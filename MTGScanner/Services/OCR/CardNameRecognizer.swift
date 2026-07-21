//
//  CardNameRecognizer.swift
//

import Foundation
import Vision
import UIKit

struct OCRResult {
    let cardName: String?
    let setCode: String?
    let collectorNumber: String?
}

final class CardNameRecognizer {

    func recognise(from image: UIImage) async -> OCRResult {
        async let name = recogniseName(from: image)
        async let metadata = recogniseMetadata(from: image)

        let cardName = await name
        let (setCode, collectorNumber) = await metadata

        return OCRResult(
            cardName: cardName,
            setCode: setCode,
            collectorNumber: collectorNumber
        )
    }
}

// MARK: - Name OCR

private extension CardNameRecognizer {

    func recogniseName(
        from image: UIImage
    ) async -> String? {

        let titleRects = [
            CGRect(x: 0.04, y: 0.02, width: 0.92, height: 0.10),
            CGRect(x: 0.04, y: 0.03, width: 0.92, height: 0.13),
            CGRect(x: 0.00, y: 0.00, width: 1.00, height: 0.16)
        ]

        for variant in portraitVariants(for: image) {
            for rect in titleRects {
                guard
                    let cropped = crop(variant, normalizedRect: rect),
                    let cgImage = cropped.cgImage
                else {
                    continue
                }

                let strings = await performOCR(cgImage: cgImage)
                AppLog.debug("[OCR NAME CROP]", strings)

                if let name = strings.compactMap(cleanNameCandidate).first {
                    return name
                }
            }
        }

        return nil
    }
}

// MARK: - Set Code + Collector Number

private extension CardNameRecognizer {
    
    func recogniseMetadata(
        from image: UIImage
    ) async -> (String?, String?) {
        
        var strings: [String] = []

        for variant in portraitVariants(for: image) {
            guard
                let cropped = crop(
                    variant,
                    normalizedRect: CGRect(
                        x: 0.00,
                        y: 0.84,
                        width: 0.55,
                        height: 0.16
                    )
                ),
                let cgImage = cropped.cgImage
            else {
                continue
            }

            let cropStrings = await performOCR(
                cgImage: cgImage
            )

            AppLog.debug("[OCR META CROP]", cropStrings)
            strings.append(contentsOf: cropStrings)
        }

        var setCode: String?
        var collectorNumber: String?
        
        for text in strings {
            
            let value = text
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .uppercased()
            
            // Extract collector number from:
            // "237/244 L"
            // "123/281"
            if collectorNumber == nil {
                
                let regex = try! NSRegularExpression(
                    pattern: #"(\d{2,4})\/(\d{2,4})"#
                )
                
                let range = NSRange(
                    location: 0,
                    length: value.utf16.count
                )
                
                if let match = regex.firstMatch(
                    in: value,
                    range: range
                ) {
                    
                    let numberRange =
                    Range(
                        match.range(at: 1),
                        in: value
                    )
                    
                    collectorNumber =
                    numberRange.map {
                        String(value[$0])
                    }
                } else if let number = collectorNumberCandidate(from: value) {
                    collectorNumber = number
                }
            }
            
            // Extract set code from:
            // "UNF • EN N ADAM PAOU"
            // "LTR • EN"
            // "MOM EN"
            if setCode == nil {
                let tokens = value.components(
                    separatedBy: CharacterSet.alphanumerics.inverted
                )

                for token in tokens {
                    let candidate = token.uppercased()

                    guard
                        candidate.count >= 2,
                        candidate.count <= 5,
                        candidate.allSatisfy({ $0.isLetter })
                    else {
                        continue
                    }

                    if ["EN", "FR", "DE", "IT", "ES", "PT", "RU", "KO", "ZH", "JA"].contains(candidate) {
                        continue
                    }

                    setCode = candidate
                    break
                }
            }
        }
        
        return (
            setCode,
            collectorNumber
        )
    }
}

// MARK: - OCR Cleanup

private extension CardNameRecognizer {

    func cleanNameCandidate(_ value: String) -> String? {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")

        guard cleaned.count >= 3, cleaned.count <= 60 else {
            return nil
        }

        let lowercased = cleaned.lowercased()

        guard
            !lowercased.contains("•"),
            !lowercased.contains(" en "),
            !lowercased.contains("/"),
            !lowercased.contains(":"),
            !lowercased.contains(".")
        else {
            return nil
        }

        let letterCount = cleaned.filter { $0.isLetter }.count
        guard letterCount >= 3 else {
            return nil
        }

        return cleaned
    }

    func collectorNumberCandidate(from value: String) -> String? {
        let regex = try? NSRegularExpression(
            pattern: #"(?:^|\D)(\d{3,4})(?:\D|$)"#
        )

        let range = NSRange(
            location: 0,
            length: value.utf16.count
        )

        guard
            let match = regex?.firstMatch(in: value, range: range),
            let numberRange = Range(match.range(at: 1), in: value)
        else {
            return nil
        }

        return String(value[numberRange])
    }
}

// MARK: - OCR

private extension CardNameRecognizer {

    func performOCR(
        cgImage: CGImage
    ) async -> [String] {

        await withCheckedContinuation {
            continuation in

            let request =
                VNRecognizeTextRequest {

                    request,
                    error in

                    guard error == nil else {

                        continuation.resume(
                            returning: []
                        )

                        return
                    }

                    let strings =
                        (request.results
                            as? [VNRecognizedTextObservation])?
                        .compactMap {
                            $0.topCandidates(1)
                                .first?
                                .string
                        } ?? []
                    AppLog.debug("[OCR FULL]", strings)
                    continuation.resume(
                        returning: strings
                    )
                }
            

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            DispatchQueue.global(
                qos: .userInitiated
            ).async {

                let handler =
                    VNImageRequestHandler(
                        cgImage: cgImage,
                        options: [:]
                    )

                try? handler.perform(
                    [request]
                )
            }
        }
    }
}

// MARK: - Crop

private extension CardNameRecognizer {
    
    func crop(
        _ image: UIImage,
        normalizedRect: CGRect
    ) -> UIImage? {
        
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        let rect = CGRect(
            x: normalizedRect.minX * CGFloat(cgImage.width),
            y: normalizedRect.minY * CGFloat(cgImage.height),
            width: normalizedRect.width * CGFloat(cgImage.width),
            height: normalizedRect.height * CGFloat(cgImage.height)
        )
        
        guard let cropped =
                cgImage.cropping(to: rect)
        else {
            return nil
        }
        
        return UIImage(
            cgImage: cropped
        )
    }
    
    private func portraitVariants(for image: UIImage) -> [UIImage] {
        guard image.size.width > image.size.height else {
            return [image]
        }

        return [
            rotate(image, radians: .pi / 2),
            rotate(image, radians: -.pi / 2)
        ]
    }

    private func rotate(_ image: UIImage, radians: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: image.size.height, height: image.size.width)
        )

        return renderer.image { context in
            context.cgContext.translateBy(x: image.size.height / 2, y: image.size.width / 2)
            context.cgContext.rotate(by: radians)
            image.draw(in: CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ))
        }
    }
}
