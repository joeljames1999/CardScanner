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
            
            for card in matches {

                print(
                    "[Scanner]",
                    card.set,
                    card.collectorNumber,
                    "illustration:",
                    card.illustrationID ?? "nil"
                )
                let matches =
                    CardDatabaseService.shared.findCards(
                        fuzzyName: recognisedName
                    )
                print (matches.count)
            }
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

        guard !isMatchingVision else {
            return
        }

        isMatchingVision = true

        defer {
            isMatchingVision = false
        }

        let artworkImage =
            image
                .artworkCrop()?
                .normalizedLandscape()

        guard let livePrint =
            await VisionFeaturePrintService.shared
                .generateFeaturePrint(
                    from: artworkImage ?? image
                )
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

        print(
            "[Scanner] Best match:",
            bestMatch.name,
            bestMatch.set,
            bestMatch.collectorNumber
        )

        // Find all printings that use the same artwork
        let artworkPrintings =
            await VisionFeaturePrintService.shared
                .matchingArtworkPrintings(
                    sourceCard: bestMatch,
                    candidates: candidates
                )

        print(
            "[Scanner] Artwork printings:",
            artworkPrintings.count
        )

        for card in artworkPrintings {

            print(
                "[Scanner] Artwork card:",
                "\(card.set.uppercased()) #\(card.collectorNumber)"
            )
        }

        if artworkPrintings.count > 1 {

            state = .selectPrinting(
                artworkPrintings.sorted {
                    $0.setName < $1.setName
                }
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


extension UIImage {

    func normalizedLandscape() -> UIImage {

        if size.width > size.height {
            return self
        }

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(
                width: size.height,
                height: size.width
            )
        )

        return renderer.image { context in

            context.cgContext.translateBy(
                x: size.height / 2,
                y: size.width / 2
            )

            context.cgContext.rotate(
                by: -.pi / 2
            )

            draw(
                in: CGRect(
                    x: -size.width / 2,
                    y: -size.height / 2,
                    width: size.width,
                    height: size.height
                )
            )
        }
    }
}
