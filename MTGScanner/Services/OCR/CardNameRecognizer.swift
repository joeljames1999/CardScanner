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
        let portrait = ensurePortrait(image)

        async let name = recogniseName(from: portrait)
        async let metadata = recogniseMetadata(from: portrait)

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

        UIImageWriteToSavedPhotosAlbum(
            image,
            nil,
            nil,
            nil
        )
        
        guard let cropped =
            crop(
                image,
                normalizedRect: CGRect(
                    x: 0,
                    y: 0,
                    width: 1,
                    height: 0.16
                )
            ),
            let cgImage = cropped.cgImage
        else {
            return nil
        }

        let strings = await performOCR(cgImage: cgImage)

        AppLog.debug("[OCR FULL]", strings)

        return strings.first
        
//        return await performOCR(
//            cgImage: cgImage
//        ).first?
//            .trimmingCharacters(
//                in: .whitespacesAndNewlines
//            )
    }
}

// MARK: - Set Code + Collector Number

private extension CardNameRecognizer {
    
    func recogniseMetadata(
        from image: UIImage
    ) async -> (String?, String?) {
        
        guard let cropped = crop(
            image,
            normalizedRect: CGRect(
                x: 0.00,
                y: 0.86,
                width: 0.35,
                height: 0.14
            )
        ),
              let cgImage = cropped.cgImage
        else {
            return (nil, nil)
        }
        
        let strings = await performOCR(
            cgImage: cgImage
        )
        
        AppLog.debug("[OCR META CROP]", strings)
        
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
    
    private func ensurePortrait(_ image: UIImage) -> UIImage {
        guard image.size.width > image.size.height else {
            return image  // already portrait
        }
        
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: image.size.height, height: image.size.width)
        )
        
        return renderer.image { context in
            context.cgContext.translateBy(x: image.size.height / 2, y: image.size.width / 2)
            context.cgContext.rotate(by: .pi / 2)
            image.draw(in: CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ))
        }
    }
}
