import UIKit
import Vision

final class VisionFeaturePrintService {

    static let shared = VisionFeaturePrintService()
    private init() {}

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
        scannedObservation: VNFeaturePrintObservation,
        candidates: [MTGCard]
    ) async -> MTGCard? {
        guard !candidates.isEmpty else { return nil }

        // Batch query all feature prints from SQLite into memory at once
        let candidateIds = candidates.map { $0.id }
        let cachedPrints = CardDatabaseService.shared.fetchFeaturePrints(for: candidateIds)

        // Spread the vector distance processing across parallel worker contexts
        let scoredCandidates: [(card: MTGCard, distance: Float)] = await withTaskGroup(of: (MTGCard, Float)?.self) { group in
            for card in candidates {
                group.addTask {
                    // Check if the card has a stored binary footprint, skip download if it's missing
                    guard let candidateObservation = cachedPrints[card.id] else {
                        return nil
                    }
                    
                    var distance: Float = 0
                    try? scannedObservation.computeDistance(&distance, to: candidateObservation)
                    return (card, distance)
                }
            }

            var results = [(card: MTGCard, distance: Float)]()
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            return results
        }

        if let winner = scoredCandidates.min(by: { $0.distance < $1.distance }) {
            print("[Vision] WINNER:", winner.card.set, winner.card.collectorNumber, "distance:", winner.distance)
            return winner.card
        }

        // Fallback: If your DB hasn't populated feature prints yet, return the first card
        return candidates.first
    }

    func matchingArtworkPrintings(
        sourceCard: MTGCard,
        candidates: [MTGCard]
    ) async -> [MTGCard] {
        let candidateIds = candidates.map { $0.id }
        let cachedPrints = CardDatabaseService.shared.fetchFeaturePrints(for: candidateIds + [sourceCard.id])
        
        guard let sourcePrint = cachedPrints[sourceCard.id] else { return [sourceCard] }
        var matches: [MTGCard] = []

        for card in candidates {
            guard let candidatePrint = cachedPrints[card.id] else { continue }
            var distance: Float = 0
            try? sourcePrint.computeDistance(&distance, to: candidatePrint)

            if distance < 0.08 {
                matches.append(card)
            }
        }
        return matches
    }
}
