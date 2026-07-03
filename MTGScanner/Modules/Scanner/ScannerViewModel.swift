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
    
    // MARK: - Voting state
    private var ocrVotes: [(name: String, setCode: String?, collectorNumber: String?)] = []
    private let requiredVotes = 3
    private let maxVotes = 5
    
    // Clock for precision benchmarking
    private let clock = ContinuousClock()

    // MARK: - Public

    func startScanning() {
        isScanning = true
        state = .scanning
        lastFoundCardName = ""
        lastAcceptedCardID = nil
        ocrVotes.removeAll()
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
        ocrVotes.removeAll()

        Task {
            try? await Task.sleep(for: .seconds(2))
            lastAcceptedCardID = nil
        }
    }

    // MARK: - Frame Entry

    func processCardImage(
        _ image: UIImage,
        ocrResult: OCRResult?
    ) {
        guard isScanning, case .scanning = state else { return }

        // Accumulate vote
        if let name = ocrResult?.cardName?.trimmingCharacters(in: .whitespacesAndNewlines),
           name.count > 2 {
            ocrVotes.append((
                name: name,
                setCode: ocrResult?.setCode?.lowercased(),
                collectorNumber: ocrResult?.collectorNumber
            ))
            print("[Scanner] Vote \(ocrVotes.count)/\(requiredVotes): '\(name)' \(ocrResult?.setCode ?? "?") #\(ocrResult?.collectorNumber ?? "?")")
        }

        guard ocrVotes.count >= requiredVotes else { return }

        // Find dominant name (must have at least 2 agreeing votes)
        let nameCounts = Dictionary(grouping: ocrVotes, by: { $0.name }).mapValues { $0.count }
        guard let dominantName = nameCounts.max(by: { $0.value < $1.value })?.key,
              nameCounts[dominantName]! >= 2 else {
            if ocrVotes.count >= maxVotes {
                print("[Scanner] No name consensus after \(maxVotes) votes — resetting")
                ocrVotes.removeAll()
            }
            return
        }

        // Among dominant name votes, find most common set+number
        let dominantVotes = ocrVotes.filter { $0.name == dominantName }
        let printingCounts = Dictionary(
            grouping: dominantVotes,
            by: { "\($0.setCode ?? "")|\($0.collectorNumber ?? "")" }
        ).mapValues { $0.count }

        let dominantPrinting = printingCounts.max(by: { $0.value < $1.value })?.key
        let parts = dominantPrinting?.components(separatedBy: "|")
        let dominantSetCode = parts?.first.flatMap { $0.isEmpty ? nil : $0 }
        let dominantCollectorNumber = parts?.last.flatMap { $0.isEmpty ? nil : $0 }

        print("[Scanner] Consensus: '\(dominantName)' set=\(dominantSetCode ?? "nil") num=\(dominantCollectorNumber ?? "nil") from \(ocrVotes.count) votes")

        ocrVotes.removeAll()

        processConsensusResult(
            image: image,
            name: dominantName,
            setCode: dominantSetCode,
            collectorNumber: dominantCollectorNumber
        )
    }

    private func processConsensusResult(
        image: UIImage,
        name: String,
        setCode: String?,
        collectorNumber: String?
    ) {
        // --------------------------------------------------
        // 1. EXACT PRINTING LOOKUP
        // --------------------------------------------------
        if let setCode, let collectorNumber {

            let exactStart = clock.now

            let exactMatches = CardDatabaseService.shared.findCards(
                setCode: setCode,
                collectorNumber: collectorNumber
            )

            print("[Timer] Exact Printing Lookup took:", clock.now - exactStart)
            print("[Scanner] Exact lookup: \(setCode) #\(collectorNumber)")
            print("[Scanner] Exact matches:", exactMatches.count)

            if exactMatches.count == 1 {
                print("[Scanner] Exact match found:", exactMatches[0].name, exactMatches[0].set, exactMatches[0].collectorNumber)
                handleMatchedCard(exactMatches[0])
                return
            }

            if exactMatches.count > 1 {
                Task { await resolvePrinting(image: image, candidates: exactMatches) }
                return
            }
        }

        // --------------------------------------------------
        // 2. NAME LOOKUP FALLBACK
        // --------------------------------------------------
        guard name != lastFoundCardName else { return }
        lastFoundCardName = name

        let dbStart = clock.now

        let matches = CardDatabaseService.shared.findCards(fuzzyName: name)

        print("[Timer] DB Name Lookup took:", clock.now - dbStart)
        print("[Scanner] Found cards:", matches.map { "\($0.set.uppercased()) #\($0.collectorNumber)" })
        print("[Scanner] OCR matches:", matches.count)

        if matches.count == 1 {
            handleMatchedCard(matches[0])
            return
        }

        if matches.count > 1 {
            Task { await resolvePrinting(image: image, candidates: matches) }
            return
        }

        print("[Scanner] No matches found")
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
