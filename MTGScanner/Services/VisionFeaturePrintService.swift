import UIKit
import Vision

struct ArtworkMatch {
    let card: MTGCard
    let distance: Float
}

final class VisionFeaturePrintService {

    static let shared = VisionFeaturePrintService()

    private init() {}

    func generateFeaturePrint(
        from image: UIImage
    ) async -> VNFeaturePrintObservation? {

        guard let cgImage = image.cgImage else {
            return nil
        }

        return await withCheckedContinuation { continuation in

            let request = VNGenerateImageFeaturePrintRequest()

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                options: [:]
            )

            DispatchQueue.global(qos: .userInitiated).async {

                do {

                    try handler.perform([request])

                    let result =
                        request.results?.first
                        as? VNFeaturePrintObservation

                    continuation.resume(
                        returning: result
                    )

                } catch {

                    continuation.resume(
                        returning: nil
                    )
                }
            }
        }
    }
    
    func featurePrint(
        for card: MTGCard
    ) async -> VNFeaturePrintObservation? {

        guard let url =
            card.imageUris?.artCrop ??
            card.imageUris?.normal
        else {
            return nil
        }

        do {

            let (data, _) =
                try await URLSession.shared
                    .data(from: url)

            guard let image =
                UIImage(data: data)?
                    .artworkCrop()?
                    .normalizedLandscape()
            else {
                return nil
            }

            return await generateFeaturePrint(
                from: image
            )

        } catch {

            return nil
        }
    }
    
    func bestMatch(
        scannedObservation: VNFeaturePrintObservation,
        candidates: [MTGCard]
    ) async -> MTGCard? {

        var bestCard: MTGCard?
        var bestDistance: Float = .greatestFiniteMagnitude

        for card in candidates {

            let candidateObservation: VNFeaturePrintObservation

            if let cached =
                await featurePrint(for: card) {

                candidateObservation = cached

            } else {

                guard let generated =
                    await featurePrint(for: card)
                else {
                    continue
                }

                candidateObservation = generated

                if let archived =
                    try? CardDatabaseService.shared
                        .generateFeaturePrint(from: generated) {

                    CardDatabaseService.shared
                        .storeFeaturePrint(
                            cardId: card.id,
                            data: archived
                        )
                }
            }

            let distance =
                distance(
                    between: scannedObservation,
                    and: candidateObservation
                )

            print(
                "[Vision]",
                card.set,
                card.collectorNumber,
                distance
            )

            if distance < bestDistance {

                bestDistance = distance
                bestCard = card
            }
        }

        guard let bestCard else {
            return nil
        }

        print(
            "[Vision] WINNER:",
            bestCard.set,
            bestCard.collectorNumber,
            "distance:",
            bestDistance
        )

        return bestCard
    }

    func matchingArtworkPrintings(
        sourceCard: MTGCard,
        candidates: [MTGCard]
    ) async -> [MTGCard] {

        guard let sourcePrint =
            await featurePrint(for: sourceCard)
        else {
            return [sourceCard]
        }

        var matches: [MTGCard] = []

        for card in candidates {

            guard let candidatePrint =
                await featurePrint(for: card)
            else {
                continue
            }

            let distance =
                distance(
                    between: sourcePrint,
                    and: candidatePrint
                )

            print(
                "[Artwork Match]",
                card.set,
                card.collectorNumber,
                distance
            )

            // Same artwork threshold
            if distance < 0.08 {

                matches.append(card)
            }
        }

        return matches
    }
    
    func artworkMatches(
        scannedObservation: VNFeaturePrintObservation,
        candidates: [MTGCard]
    ) async -> [ArtworkMatch] {

        var results: [ArtworkMatch] = []

        for card in candidates {

            let candidateObservation: VNFeaturePrintObservation

            if let cached = await featurePrint(for: card) {

                candidateObservation = cached

            } else {

                guard let generated =
                    await featurePrint(for: card)
                else {
                    continue
                }

                candidateObservation = generated
            }

            let distance = distance(
                between: scannedObservation,
                and: candidateObservation
            )

            print(
                "[Vision]",
                card.set,
                "#\(card.collectorNumber)",
                distance
            )

            results.append(
                ArtworkMatch(
                    card: card,
                    distance: distance
                )
            )
        }

        return results.sorted {
            $0.distance < $1.distance
        }
    }
    
    func distance(
        between a: VNFeaturePrintObservation,
        and b: VNFeaturePrintObservation
    ) -> Float {

        var distance: Float = 0

        try? a.computeDistance(
            &distance,
            to: b
        )

        return distance
    }
}


extension UIImage {

    func artworkCrop() -> UIImage? {

        guard let cgImage else {
            return nil
        }

        let rect = CGRect(
            x: size.width * 0.07,
            y: size.height * 0.12,
            width: size.width * 0.86,
            height: size.height * 0.32
        )

        let scale = self.scale

        let cropRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )

        guard let cropped =
            cgImage.cropping(to: cropRect)
        else {
            return nil
        }

        return UIImage(
            cgImage: cropped,
            scale: scale,
            orientation: imageOrientation
        )
    }
}
