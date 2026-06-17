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
            
            let matches = CardDatabaseService.shared.findCards(
                fuzzyName: recognisedName
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
            // OCR failed completely
            state = .error(
                "Could not identify card"
            )
        }
    }

    // MARK: - Vision Matching
    
    private func resolvePrinting(
        image: UIImage,
        candidates: [MTGCard]
    ) async {

        guard !isMatchingVision else {
            return
        }

        isMatchingVision = true

        defer {
            isMatchingVision = false
        }

        guard let livePrint =
            await VisionFeaturePrintService.shared
                .generateFeaturePrint(from: image)
        else {
            state = .selectPrinting(candidates)
            return
        }

        guard let bestMatch =
            await VisionFeaturePrintService.shared
                .bestMatch(
                    scannedObservation: livePrint,
                    candidates: candidates
                )
        else {
            state = .selectPrinting(candidates)
            return
        }

        handleMatchedCard(bestMatch)
    }

    // MARK: - Result Handling

    private func handleMatchedCard(_ card: MTGCard) {

        guard lastAcceptedCardID != card.id else { return }
        lastAcceptedCardID = card.id

        SessionStore.shared.addOrIncrement(card: card)

        state = .found(card)
    }
}
