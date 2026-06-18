import UIKit
import Vision

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
                UIImage(data: data)
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
                await featurePrint(
                        for: card
                    ) {

                candidateObservation = cached

            } else {

                guard let generated =
                    await featurePrint(
                        for: card
                    )
                else {
                    continue
                }

                candidateObservation = generated

                if let archived =
                    try? CardDatabaseService.shared
                        .generateFeaturePrint(
                            from: generated
                        ) {

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

            if distance < bestDistance {

                bestDistance = distance
                bestCard = card
            }
        }

        return bestCard
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
