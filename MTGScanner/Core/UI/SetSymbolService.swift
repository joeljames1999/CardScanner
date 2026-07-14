//
//  SetSymbolService.swift
//  TcgScanner
//

import UIKit

@MainActor
final class SetSymbolService {

    static let shared = SetSymbolService()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlightRequests: [String: [(UIImage?) -> Void]] = [:]

    private lazy var cacheDirectory: URL = {
        let url = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
            .appendingPathComponent(
                "SetSymbols",
                isDirectory: true
            )

        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )

        return url
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "TCGCompanion-iOS/1.0"
        ]
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: Public

    func image(
        for setCode: String,
        completion: @escaping (UIImage?) -> Void
    ) {
        let code = setCode.lowercased()

        if let image = cache.object(forKey: code as NSString) {
            completion(image)
            return
        }

        let diskURL = cacheDirectory
            .appendingPathComponent("\(code).png")

        if
            let data = try? Data(contentsOf: diskURL),
            let image = UIImage(data: data)
        {
            let templateImage = image.withRenderingMode(.alwaysTemplate)
            cache.setObject(templateImage, forKey: code as NSString)
            completion(templateImage)
            return
        }

        if inFlightRequests[code] != nil {
            inFlightRequests[code]?.append(completion)
            return
        }

        inFlightRequests[code] = [completion]

        Task { [weak self] in
            guard let self else { return }

            let image = await self.downloadSymbol(setCode: code)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                let completions = self.inFlightRequests.removeValue(forKey: code) ?? []
                completions.forEach { $0(image) }
            }
        }
    }

    func clearCache() {
        cache.removeAllObjects()

        try? FileManager.default.removeItem(
            at: cacheDirectory
        )

        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }
}

// MARK: - Download

private extension SetSymbolService {

    struct ScryfallSet: Decodable {
        let iconSVGURI: URL

        enum CodingKeys: String, CodingKey {
            case iconSVGURI = "icon_svg_uri"
        }
    }

    func downloadSymbol(setCode: String) async -> UIImage? {
        guard let setURL = URL(string: "https://api.scryfall.com/sets/\(setCode)") else {
            return nil
        }

        do {
            let (setData, setResponse) = try await session.data(from: setURL)

            guard
                let setHTTPResponse = setResponse as? HTTPURLResponse,
                setHTTPResponse.statusCode == 200
            else {
                return nil
            }

            let scryfallSet = try JSONDecoder().decode(
                ScryfallSet.self,
                from: setData
            )

            let (svgData, svgResponse) = try await session.data(
                from: scryfallSet.iconSVGURI
            )

            guard
                let svgHTTPResponse = svgResponse as? HTTPURLResponse,
                svgHTTPResponse.statusCode == 200,
                let image = SetSymbolSVGRenderer.image(from: svgData)
            else {
                return nil
            }

            let templateImage = image.withRenderingMode(.alwaysTemplate)
            cache.setObject(templateImage, forKey: setCode as NSString)

            if let pngData = image.pngData() {
                let diskURL = cacheDirectory
                    .appendingPathComponent("\(setCode).png")

                try? pngData.write(to: diskURL)
            }

            return templateImage
        } catch {
            return nil
        }
    }
}

// MARK: - SVG Rendering

private enum SetSymbolSVGRenderer {

    static func image(from data: Data) -> UIImage? {
        guard
            let svg = String(data: data, encoding: .utf8),
            let viewBox = parseViewBox(from: svg)
        else {
            return nil
        }

        let pathStrings = parsePathStrings(from: svg)
        guard !pathStrings.isEmpty else {
            return nil
        }

        let symbolPath = UIBezierPath()

        for pathString in pathStrings {
            guard let path = SVGPathParser(pathString).parse() else {
                continue
            }

            symbolPath.append(path)
        }

        guard !symbolPath.isEmpty else {
            return nil
        }

        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.black.setFill()

            let scale = min(
                size.width / viewBox.width,
                size.height / viewBox.height
            )
            let xOffset = (size.width - viewBox.width * scale) / 2
            let yOffset = (size.height - viewBox.height * scale) / 2

            context.cgContext.translateBy(x: xOffset, y: yOffset)
            context.cgContext.scaleBy(x: scale, y: scale)
            context.cgContext.translateBy(x: -viewBox.minX, y: -viewBox.minY)

            symbolPath.fill()
        }
    }

    private static func parseViewBox(from svg: String) -> CGRect? {
        guard
            let range = svg.range(
                of: #"viewBox\s*=\s*"([^"]+)""#,
                options: .regularExpression
            )
        else {
            return nil
        }

        let match = String(svg[range])
        guard
            let valueRange = match.range(of: #""[^"]+""#, options: .regularExpression)
        else {
            return nil
        }

        let values = match[valueRange]
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            .split { $0 == " " || $0 == "," }
            .compactMap { Double($0) }

        guard values.count == 4 else {
            return nil
        }

        return CGRect(
            x: values[0],
            y: values[1],
            width: values[2],
            height: values[3]
        )
    }

    private static func parsePathStrings(from svg: String) -> [String] {
        guard
            let regex = try? NSRegularExpression(
                pattern: #"<path[^>]*\sd\s*=\s*"([^"]+)""#,
                options: [.caseInsensitive]
            )
        else {
            return []
        }

        let range = NSRange(svg.startIndex..<svg.endIndex, in: svg)
        return regex.matches(in: svg, range: range).compactMap { match in
            guard
                match.numberOfRanges > 1,
                let pathRange = Range(match.range(at: 1), in: svg)
            else {
                return nil
            }

            return String(svg[pathRange])
        }
    }
}

private final class SVGPathParser {

    private let characters: [Character]
    private var index = 0
    private var currentPoint = CGPoint.zero
    private var subpathStart = CGPoint.zero
    private var lastCubicControlPoint: CGPoint?
    private var lastQuadraticControlPoint: CGPoint?

    init(_ pathString: String) {
        characters = Array(pathString)
    }

    func parse() -> UIBezierPath? {
        let path = UIBezierPath()
        var activeCommand: Character?

        while index < characters.count {
            skipSeparators()
            let startingIndex = index

            if let command = currentCharacter, command.isSVGCommand {
                activeCommand = command
                index += 1
            }

            guard let command = activeCommand else {
                return nil
            }

            if !apply(command, to: path) {
                return nil
            }

            guard index > startingIndex else {
                return nil
            }
        }

        return path
    }

    private func apply(_ command: Character, to path: UIBezierPath) -> Bool {
        switch command {
        case "M", "m":
            guard let point = parsePoint(relativeTo: command.isLowercase ? currentPoint : nil) else {
                return false
            }
            path.move(to: point)
            currentPoint = point
            subpathStart = point
            lastCubicControlPoint = nil
            lastQuadraticControlPoint = nil

            while let point = parsePoint(relativeTo: command.isLowercase ? currentPoint : nil) {
                path.addLine(to: point)
                currentPoint = point
            }

        case "L", "l":
            while let point = parsePoint(relativeTo: command.isLowercase ? currentPoint : nil) {
                path.addLine(to: point)
                currentPoint = point
            }
            lastCubicControlPoint = nil
            lastQuadraticControlPoint = nil

        case "H", "h":
            while let x = parseNumber() {
                let point = CGPoint(
                    x: command.isLowercase ? currentPoint.x + x : x,
                    y: currentPoint.y
                )
                path.addLine(to: point)
                currentPoint = point
            }
            lastCubicControlPoint = nil
            lastQuadraticControlPoint = nil

        case "V", "v":
            while let y = parseNumber() {
                let point = CGPoint(
                    x: currentPoint.x,
                    y: command.isLowercase ? currentPoint.y + y : y
                )
                path.addLine(to: point)
                currentPoint = point
            }
            lastCubicControlPoint = nil
            lastQuadraticControlPoint = nil

        case "C", "c":
            while
                let firstControlPoint = parsePoint(relativeTo: command.isLowercase ? currentPoint : nil),
                let secondControlPoint = parsePoint(relativeTo: command.isLowercase ? currentPoint : nil),
                let endPoint = parsePoint(relativeTo: command.isLowercase ? currentPoint : nil)
            {
                path.addCurve(
                    to: endPoint,
                    controlPoint1: firstControlPoint,
                    controlPoint2: secondControlPoint
                )
                currentPoint = endPoint
                lastCubicControlPoint = secondControlPoint
                lastQuadraticControlPoint = nil
            }

        case "S", "s":
            while
                let secondControlPoint = parsePoint(relativeTo: command.isLowercase ? currentPoint : nil),
                let endPoint = parsePoint(relativeTo: command.isLowercase ? currentPoint : nil)
            {
                let firstControlPoint = reflectedPoint(
                    lastCubicControlPoint,
                    around: currentPoint
                )
                path.addCurve(
                    to: endPoint,
                    controlPoint1: firstControlPoint,
                    controlPoint2: secondControlPoint
                )
                currentPoint = endPoint
                lastCubicControlPoint = secondControlPoint
                lastQuadraticControlPoint = nil
            }

        case "Q", "q":
            while
                let controlPoint = parsePoint(relativeTo: command.isLowercase ? currentPoint : nil),
                let endPoint = parsePoint(relativeTo: command.isLowercase ? currentPoint : nil)
            {
                path.addQuadCurve(to: endPoint, controlPoint: controlPoint)
                currentPoint = endPoint
                lastQuadraticControlPoint = controlPoint
                lastCubicControlPoint = nil
            }

        case "T", "t":
            while let endPoint = parsePoint(relativeTo: command.isLowercase ? currentPoint : nil) {
                let controlPoint = reflectedPoint(
                    lastQuadraticControlPoint,
                    around: currentPoint
                )
                path.addQuadCurve(to: endPoint, controlPoint: controlPoint)
                currentPoint = endPoint
                lastQuadraticControlPoint = controlPoint
                lastCubicControlPoint = nil
            }

        case "A", "a":
            while
                let _ = parseNumber(),
                let _ = parseNumber(),
                let _ = parseNumber(),
                let _ = parseNumber(),
                let _ = parseNumber(),
                let x = parseNumber(),
                let y = parseNumber()
            {
                let point = CGPoint(
                    x: command.isLowercase ? currentPoint.x + x : x,
                    y: command.isLowercase ? currentPoint.y + y : y
                )
                path.addLine(to: point)
                currentPoint = point
            }
            lastCubicControlPoint = nil
            lastQuadraticControlPoint = nil

        case "Z", "z":
            path.close()
            currentPoint = subpathStart
            lastCubicControlPoint = nil
            lastQuadraticControlPoint = nil

        default:
            return false
        }

        return true
    }

    private var currentCharacter: Character? {
        guard index < characters.count else { return nil }
        return characters[index]
    }

    private func parsePoint(relativeTo relativePoint: CGPoint?) -> CGPoint? {
        let savedIndex = index

        guard let x = parseNumber(), let y = parseNumber() else {
            index = savedIndex
            return nil
        }

        if let relativePoint {
            return CGPoint(x: relativePoint.x + x, y: relativePoint.y + y)
        }

        return CGPoint(x: x, y: y)
    }

    private func parseNumber() -> CGFloat? {
        skipSeparators()

        let startIndex = index
        var hasDigit = false

        if currentCharacter == "-" || currentCharacter == "+" {
            index += 1
        }

        while let character = currentCharacter, character.isNumber {
            hasDigit = true
            index += 1
        }

        if currentCharacter == "." {
            index += 1

            while let character = currentCharacter, character.isNumber {
                hasDigit = true
                index += 1
            }
        }

        if currentCharacter == "e" || currentCharacter == "E" {
            let exponentIndex = index
            index += 1

            if currentCharacter == "-" || currentCharacter == "+" {
                index += 1
            }

            var hasExponentDigit = false
            while let character = currentCharacter, character.isNumber {
                hasExponentDigit = true
                index += 1
            }

            if !hasExponentDigit {
                index = exponentIndex
            }
        }

        guard hasDigit else {
            index = startIndex
            return nil
        }

        let value = String(characters[startIndex..<index])
        skipSeparators()

        guard let number = Double(value) else {
            return nil
        }

        return CGFloat(number)
    }

    private func skipSeparators() {
        while let character = currentCharacter,
              character == " " || character == "\n" || character == "\t" || character == "," {
            index += 1
        }
    }

    private func reflectedPoint(
        _ point: CGPoint?,
        around center: CGPoint
    ) -> CGPoint {
        guard let point else { return center }

        return CGPoint(
            x: center.x * 2 - point.x,
            y: center.y * 2 - point.y
        )
    }
}

private extension Character {

    var isSVGCommand: Bool {
        "MmLlHhVvCcSsQqTtAaZz".contains(self)
    }

    var isLowercase: Bool {
        String(self).lowercased() == String(self)
    }
}
