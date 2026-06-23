import Photos
import Foundation
import Combine
import UIKit
import Vision

// MARK: - Scanner State

enum ScannerState: Equatable {
    case idle
    case scanning
    case found(MTGCard)
    case selectPrinting([MTGCard])
    case error(String)

    static func == (lhs: ScannerState, rhs: ScannerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.scanning, .scanning):
            return true
        case (.found(let a), .found(let b)):
            return a.id == b.id
        case (.selectPrinting(let a), .selectPrinting(let b)):
            return a.map(\.id) == b.map(\.id)
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - ScannerViewModel

@MainActor
final class ScannerViewModel: ObservableObject {

    @Published private(set) var state: ScannerState = .idle
    @Published var isScanning: Bool = false

    private let scryfallService = ScryfallService()
    private var lookupTask: Task<Void, Never>?

    private var lastFoundCardName: String = ""
    private var lastAcceptedCardID: String?
    private var isMatchingVision = false
    
    // Clock for precision benchmarking
    private let clock = ContinuousClock()

    // MARK: - Public

    func startScanning() {
        isScanning = true
        state = .scanning
        lastFoundCardName = ""
        lastAcceptedCardID = nil
    }

    func stopScanning() {
        isScanning = false
        lookupTask?.cancel()
        state = .idle
    }

    func resetToScanning() {
        lookupTask?.cancel()
        state = .scanning
        lastFoundCardName = ""

        Task {
            try? await Task.sleep(for: .seconds(2))
            lastAcceptedCardID = nil
        }
    }

    // MARK: - Frame Entry

    func processCardImage(
        _ image: UIImage,
        recognisedName: String?
    ) {
        guard isScanning, case .scanning = state else { return }
        
        // 1. OCR PATH (fast win)
        if let recognisedName,
           recognisedName.count > 2,
           recognisedName != lastFoundCardName {
            
            lastFoundCardName = recognisedName
            
            // --- TIMER START: DB Query ---
            let dbStart = clock.now
            let matches = CardDatabaseService.shared.findCards(fuzzyName: recognisedName)
            let dbDuration = clock.now - dbStart
            print("[Timer] DB Name Lookup took: \(dbDuration)")
            
            print(
                "[Scanner] Found cards:",
                matches.map {
                    "\($0.set.uppercased()) #\($0.collectorNumber)"
                }
            )
            print(
                "[Scanner] OCR matches:",
                matches.count
            )
            
            if matches.count == 1 {
                handleMatchedCard(matches[0])
                return
            }
            
            if matches.count > 1 {
                Task {
                    await resolvePrinting(
                        image: image,
                        candidates: matches
                    )
                }
                return
            }
            return
        }
    }
    
    // MARK: - Vision Matching
    
    private func resolvePrinting(
        image: UIImage,
        candidates: [MTGCard]
    ) async {

        guard !isMatchingVision else { return }
        isMatchingVision = true
        defer { isMatchingVision = false }

        // --- FIXED BUG: Call bestMatch directly passing the original image frame snapshot ---
        let matchStart = clock.now
        guard let bestMatch = await VisionFeaturePrintService.shared
            .bestMatch(scannedImage: image, candidates: candidates)
        else {
            state = .selectPrinting(candidates)
            return
        }
        let matchDuration = clock.now - matchStart
        print("[Timer] Vision Best Match Comparison took: \(matchDuration)")

        print("[Scanner] Best match:", bestMatch.name, bestMatch.set, bestMatch.collectorNumber)

        // Fast SQL grouping using your optimized index
        let groupStart = clock.now
        let sharedArtworkPrintings: [MTGCard]
        
        if let illustrationID = bestMatch.illustrationID, !illustrationID.isEmpty {
            let allSharedArtworkPrintings = CardDatabaseService.shared.cards(withIllustrationID: illustrationID)
            sharedArtworkPrintings = allSharedArtworkPrintings.filter {
                $0.illustrationID == illustrationID
            }
            let groupDuration = clock.now - groupStart
            print("[Timer] DB Illustration ID Fetch (\(sharedArtworkPrintings.count) prints) took: \(groupDuration)")
            print("[Scanner] Grouped by illustrationID:", illustrationID, "→", sharedArtworkPrintings.count, "printings")
        } else {
            // Fallback: dual-vector context matching grouping
            sharedArtworkPrintings = await VisionFeaturePrintService.shared
                .matchingArtworkPrintings(sourceCard: bestMatch, candidates: candidates)
            let groupDuration = clock.now - groupStart
            print("[Timer] Vision Fallback Grouping took: \(groupDuration)")
            print("[Scanner] Grouped by artwork vision →", sharedArtworkPrintings.count, "printings")
        }

        if sharedArtworkPrintings.count > 1 {
            state = .selectPrinting(
                sharedArtworkPrintings.sorted { $0.setName < $1.setName }
            )
        } else {
            handleMatchedCard(bestMatch)
        }
    }


    // MARK: - Result Handling

    private func handleMatchedCard(_ card: MTGCard) {
        guard lastAcceptedCardID != card.id else { return }
        lastAcceptedCardID = card.id
        state = .found(card)
    }
}
