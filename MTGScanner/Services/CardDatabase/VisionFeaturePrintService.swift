import UIKit
import Vision

final class VisionFeaturePrintService {

    static let shared = VisionFeaturePrintService()
    private init() {}

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
    
    /// Matches scanned cards against candidates instantly offline using parallel CPU threads
    func bestMatch(
        scannedImage: UIImage, // Pass the original camera snapshot frame here
        candidates: [MTGCard]
    ) async -> MTGCard? {
        guard !candidates.isEmpty else { return nil }

        // 1. Generate BOTH live camera vector targets
        let croppedLiveImage = scannedImage.artworkCrop()?.normalizedLandscape() ?? scannedImage
        let fullLiveImage = scannedImage.normalizedLandscape()
        
        guard let livePrintCropped = await generateFeaturePrint(from: croppedLiveImage),
              let livePrintFull = await generateFeaturePrint(from: fullLiveImage) else {
            return candidates.first
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

        // 2. Concurrently evaluate candidates across multiple CPU cores
        let scoredCandidates: [(card: MTGCard, distance: Float)] = await withTaskGroup(of: (MTGCard, Float)?.self) { group in
            for card in candidates {
                group.addTask {
                    guard let vectors = cachedPrints[card.id] else { return nil }
                    
                    var bestCardDistance: Float = .greatestFiniteMagnitude
                    
                    // Test 1: Compare tight crop layout vectors (Standard Cards)
                    if let cachedCrop = vectors.cropped {
                        var distCrop: Float = .greatestFiniteMagnitude
                        try? livePrintCropped.computeDistance(&distCrop, to: cachedCrop)
                        if distCrop < bestCardDistance { bestCardDistance = distCrop }
                    }
                    
                    // Test 2: Compare full canvas vectors (Borderless/Full Art/Showcase Cards)
                    if let cachedFull = vectors.full {
                        var distFull: Float = .greatestFiniteMagnitude
                        try? livePrintFull.computeDistance(&distFull, to: cachedFull)
                        if distFull < bestCardDistance { bestCardDistance = distFull }
                    }
                    
                    return (card, bestCardDistance)
                }
            }

            var results = [(card: MTGCard, distance: Float)]()
            for await result in group { if let result = result { results.append(result) } }
            return results
        }

        // 3. Return the absolute best match across both frame style variants
        if let winner = scoredCandidates.min(by: { $0.distance < $1.distance }) {
            AppLog.debug("[Vision] Universal Winner Determined:", winner.card.set, winner.card.collectorNumber, "Confidence Distance Score:", winner.distance)
            return winner.card
        }

        return candidates.first
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
