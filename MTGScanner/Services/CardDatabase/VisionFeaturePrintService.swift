import UIKit
import Vision

final class VisionFeaturePrintService {

    static let shared = VisionFeaturePrintService()
    private init() {}

    struct VisualMatch {
        let card: MTGCard
        let distance: Float
        let nextBestDistance: Float?
    }

    private struct CachedFeaturePrints {
        let cropped: VNFeaturePrintObservation?
        let full: VNFeaturePrintObservation?
    }

    func generateFeaturePrint(from image: UIImage) async -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    let result = request.results?.first as? VNFeaturePrintObservation
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Matches scanned cards against candidates instantly offline using parallel CPU threads.
    func bestMatch(
        scannedImage: UIImage,
        candidates: [MTGCard]
    ) async -> MTGCard? {
        await closestVisualMatch(
            scannedImage: scannedImage,
            candidates: candidates
        )?.card ?? candidates.first
    }

    /// Returns nil when no cached visual evidence is available.
    func closestVisualMatch(
        scannedImage: UIImage,
        candidates: [MTGCard]
    ) async -> VisualMatch? {
        let scoredCandidates = await scoredVisualMatches(
            scannedImage: scannedImage,
            candidates: candidates
        )

        guard let winner = scoredCandidates.first else {
            return nil
        }

        AppLog.debug(
            "[Vision] Universal Winner Determined:",
            winner.card.set,
            winner.card.collectorNumber,
            "Confidence Distance Score:",
            winner.distance
        )

        return VisualMatch(
            card: winner.card,
            distance: winner.distance,
            nextBestDistance: scoredCandidates.dropFirst().first?.distance
        )
    }

    func confidentVisualMatch(
        scannedImage: UIImage,
        candidates: [MTGCard]
    ) async -> VisualMatch? {
        guard let match = await closestVisualMatch(
            scannedImage: scannedImage,
            candidates: candidates
        ) else {
            return nil
        }

        let maximumDistance: Float = 0.35
        let minimumDistanceGap: Float = 0.05
        let maximumDistanceRatio: Float = 0.86

        guard match.distance <= maximumDistance else {
            AppLog.debug("[Vision] Rejecting visual match; distance too high:", match.distance)
            return nil
        }

        if let nextBestDistance = match.nextBestDistance {
            let hasClearGap = nextBestDistance - match.distance >= minimumDistanceGap
            let hasClearRatio = match.distance / max(nextBestDistance, 0.001) <= maximumDistanceRatio

            guard hasClearGap || hasClearRatio else {
                AppLog.debug(
                    "[Vision] Rejecting visual match; runner-up too close:",
                    match.distance,
                    nextBestDistance
                )
                return nil
            }
        }

        return match
    }

    private func scoredVisualMatches(
        scannedImage: UIImage,
        candidates: [MTGCard]
    ) async -> [(card: MTGCard, distance: Float)] {
        guard !candidates.isEmpty else { return [] }

        let croppedLiveImage = scannedImage.artworkCrop()?.normalizedLandscape() ?? scannedImage
        let fullLiveImage = scannedImage.normalizedLandscape()
        
        guard
            let livePrintCropped = await generateFeaturePrint(from: croppedLiveImage),
            let livePrintFull = await generateFeaturePrint(from: fullLiveImage)
        else {
            return []
        }

        let cachedPrints = Dictionary(
            uniqueKeysWithValues: candidates.compactMap { card -> (String, CachedFeaturePrints)? in
                guard let record = try? AppDatabase.shared.featurePrints.featurePrint(for: card.id) else {
                    return nil
                }

                let croppedData = record.croppedFeaturePrint ?? record.featurePrint
                let fullData = record.fullFeaturePrint ?? record.featurePrint

                let cachedPrints = CachedFeaturePrints(
                    cropped: croppedData.flatMap { try? unarchiveFeaturePrint(from: $0) },
                    full: fullData.flatMap { try? unarchiveFeaturePrint(from: $0) }
                )

                guard cachedPrints.cropped != nil || cachedPrints.full != nil else {
                    return nil
                }

                return (card.id, cachedPrints)
            }
        )

        guard !cachedPrints.isEmpty else {
            return []
        }

        let scoredCandidates: [(card: MTGCard, distance: Float)] = await withTaskGroup(of: (MTGCard, Float)?.self) { group in
            for card in candidates {
                group.addTask {
                    guard let vectors = cachedPrints[card.id] else { return nil }
                    
                    var bestCardDistance: Float = .greatestFiniteMagnitude
                    
                    if let cachedCrop = vectors.cropped {
                        var distCrop: Float = .greatestFiniteMagnitude
                        try? livePrintCropped.computeDistance(&distCrop, to: cachedCrop)
                        bestCardDistance = min(bestCardDistance, distCrop)
                    }
                    
                    if let cachedFull = vectors.full {
                        var distFull: Float = .greatestFiniteMagnitude
                        try? livePrintFull.computeDistance(&distFull, to: cachedFull)
                        bestCardDistance = min(bestCardDistance, distFull)
                    }
                    
                    return (card, bestCardDistance)
                }
            }

            var results = [(card: MTGCard, distance: Float)]()
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
            return results
        }

        return scoredCandidates.sorted { $0.distance < $1.distance }
    }


    /// Helper method to lazily download missing image assets and cache their vectors on demand
    private func downloadAndCacheFeaturePrint(for card: MTGCard) async -> VNFeaturePrintObservation? {
        guard let url = card.imageUris?.artCrop ?? card.imageUris?.normal else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            guard
                let image = UIImage(data: data),
                let observation = await generateFeaturePrint(from: image)
            else {
                return nil
            }

            let archived = try archiveFeaturePrint(observation)

            try AppDatabase.shared.featurePrints.save(
                cardID: card.id,
                featurePrint: archived,
                croppedFeaturePrint: nil,
                fullFeaturePrint: nil
            )

            return observation
        } catch {
            AppLog.debug("[Vision] Failed saving feature print for \(card.name):", error)
            return nil
        }
    }

    func matchingArtworkPrintings(
        sourceCard: MTGCard,
        candidates: [MTGCard]
    ) async -> [MTGCard] {

        let ids = candidates.map(\.id) + [sourceCard.id]

        let cachedPrints = Dictionary(
            uniqueKeysWithValues: ids.compactMap { id -> (String, VNFeaturePrintObservation)? in

                guard
                    let record = try? AppDatabase.shared.featurePrints.featurePrint(for: id),
                    let data = record.featurePrint,
                    let observation = try? unarchiveFeaturePrint(from: data)
                else {
                    return nil
                }

                return (id, observation)
            }
        )

        guard let sourcePrint = cachedPrints[sourceCard.id] else {
            return [sourceCard]
        }

        var matches: [MTGCard] = []

        for card in candidates {

            guard let candidatePrint = cachedPrints[card.id] else {
                continue
            }

            var distance: Float = 0

            do {
                try sourcePrint.computeDistance(
                    &distance,
                    to: candidatePrint
                )

                if distance < 0.08 {
                    matches.append(card)
                }

            } catch {
                AppLog.debug("[Vision] Failed comparing \(sourceCard.name) to \(card.name):", error)
            }
        }

        return matches.isEmpty ? [sourceCard] : matches
    }
    
    private func archiveFeaturePrint(
        _ observation: VNFeaturePrintObservation
    ) throws -> Data {

        try NSKeyedArchiver.archivedData(
            withRootObject: observation,
            requiringSecureCoding: true
        )
    }
    
    private func unarchiveFeaturePrint(
        from data: Data
    ) throws -> VNFeaturePrintObservation {

        guard
            let observation = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self,
                from: data
            )
        else {
            throw NSError(
                domain: "VisionFeaturePrintService",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Could not unarchive VNFeaturePrintObservation"
                ]
            )
        }

        return observation
    }
    
}
