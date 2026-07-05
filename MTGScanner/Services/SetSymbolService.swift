//
//  SetSymbolService.swift
//  TcgScanner
//

import UIKit

final class SetSymbolService {

    static let shared = SetSymbolService()

    private let cache = NSCache<NSString, UIImage>()

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

    private init() {}

    // MARK: Public

    func image(
        for setCode: String,
        completion: @escaping (UIImage?) -> Void
    ) {

        let code = setCode.lowercased()

        // Memory cache

        if let image = cache.object(
            forKey: code as NSString
        ) {

            completion(image)
            return
        }

        // Disk cache

        let diskURL = cacheDirectory
            .appendingPathComponent("\(code).png")

        if
            let data = try? Data(contentsOf: diskURL),
            let image = UIImage(data: data)
        {

            cache.setObject(
                image,
                forKey: code as NSString
            )

            completion(image)
            return
        }

        // Download

        downloadSymbol(
            setCode: code,
            completion: completion
        )
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

    func downloadSymbol(
        setCode: String,
        completion: @escaping (UIImage?) -> Void
    ) {

        // Scryfall PNG endpoint
        guard let url = URL(
            string: "https://cards.scryfall.io/file/scryfall-symbols/sets/\(setCode).png"
        ) else {

            DispatchQueue.main.async {
                completion(nil)
            }

            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in

            guard
                let self,
                error == nil,
                let http = response as? HTTPURLResponse,
                http.statusCode == 200,
                let data,
                let image = UIImage(data: data)
            else {

                DispatchQueue.main.async {
                    completion(nil)
                }

                return
            }

            self.cache.setObject(
                image,
                forKey: setCode as NSString
            )

            let diskURL = self.cacheDirectory
                .appendingPathComponent("\(setCode).png")

            try? data.write(to: diskURL)

            DispatchQueue.main.async {
                completion(image)
            }

        }.resume()
    }
}
