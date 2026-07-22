import Foundation
import Combine
import UIKit

// MARK: - Scanner State

enum ScannerState: Equatable {

    case idle
    case scanning
    case found(MTGCard)
    case selectPrinting([MTGCard])
    case error(String)

    static func == (
        lhs: ScannerState,
        rhs: ScannerState
    ) -> Bool {

        switch (lhs, rhs) {

        case (.idle, .idle),
             (.scanning, .scanning):
            return true

        case (.found(let lhsCard), .found(let rhsCard)):
            return lhsCard.id == rhsCard.id

        case (.selectPrinting(let lhsCards), .selectPrinting(let rhsCards)):
            return lhsCards.map(\.id) == rhsCards.map(\.id)

        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage

        default:
            return false
        }
    }
}

// MARK: - Scan Match

private struct ScanMatch {
    let candidates: [MTGCard]
    let selectedCard: MTGCard?
    let evidence: ScanEvidence

    var shouldShowPrintingSelection: Bool {
        switch evidence {
        case .exactMetadata,
             .exactNameAndMetadata:
            return false

        case .visualArtwork:
            return !candidates.isEmpty

        case .nameOnly:
            return candidates.count > 1
        }
    }
}

private enum ScanEvidence {
    case exactMetadata
    case exactNameAndMetadata
    case visualArtwork
    case nameOnly
}

// MARK: - ScannerViewModel

@MainActor
final class ScannerViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var state: ScannerState = .idle
    @Published var isScanning: Bool = false
    @Published private(set) var isLookingUp: Bool = false

    // MARK: - Private

    private let repository: CardRepository
    private var lookupTask: Task<Void, Never>?
    private var lastLookupKey: String = ""

    private let cardCaptureService = CardCaptureService()
    private let cardNameRecognizer = CardNameRecognizer()

    // MARK: - Init

    init(
        repository: CardRepository = AppDatabase.shared.cards
    ) {
        self.repository = repository
    }

    deinit {
        lookupTask?.cancel()
    }

    // MARK: - Scanning Control

    func startScanning() {
        lookupTask?.cancel()
        lookupTask = nil
        lastLookupKey = ""
        isScanning = true
        isLookingUp = false
        state = .scanning
    }

    func stopScanning() {
        lookupTask?.cancel()
        lookupTask = nil
        isScanning = false
        isLookingUp = false
        state = .idle
    }

    func resetToScanning() {
        lookupTask?.cancel()
        lookupTask = nil
        lastLookupKey = ""
        isScanning = true
        isLookingUp = false
        state = .scanning
    }

    func resetToIdle() {
        lookupTask?.cancel()
        lookupTask = nil
        lastLookupKey = ""
        isScanning = false
        isLookingUp = false
        state = .idle
    }

    func resetAfterPresentation() {
        resetToScanning()
    }

    // MARK: - Image Processing

    func processCardImage(
        _ image: UIImage,
        ocrResult: OCRResult? = nil
    ) {
        guard isScanning else {
            return
        }

        guard !isLookingUp else {
            return
        }

        Task {
            await processImage(
                image,
                ocrResult: ocrResult
            )
        }
    }

    private func processImage(
        _ image: UIImage,
        ocrResult: OCRResult?
    ) async {

        guard isScanning else {
            return
        }

        let result = if let ocrResult {
            ocrResult
        } else {
            await cardNameRecognizer.recognise(from: image)
        }

        guard
            result.cardName != nil ||
            (result.setCode != nil && result.collectorNumber != nil)
        else {
            return
        }

        lookupCard(
            name: result.cardName,
            setCode: result.setCode,
            collectorNumber: result.collectorNumber,
            scannedImage: image
        )
    }

    // MARK: - Manual Name Handling

    func handleDetectedName(
        _ name: String
    ) {

        let cleaned = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleaned.isEmpty else {
            return
        }

        lookupCard(
            name: cleaned,
            setCode: nil,
            collectorNumber: nil,
            scannedImage: nil
        )
    }

    // MARK: - Lookup

    private func lookupCard(
        name: String?,
        setCode: String?,
        collectorNumber: String?,
        scannedImage: UIImage?
    ) {

        let lookupKey = [
            name ?? "",
            setCode ?? "",
            collectorNumber ?? ""
        ]
        .joined(separator: "|")
        .lowercased()

        guard lookupKey != lastLookupKey else {
            return
        }

        lastLookupKey = lookupKey

        lookupTask?.cancel()

        isLookingUp = true
        state = .scanning

        lookupTask = Task { [repository] in

            do {

                let match = try await Self.resolveScanMatch(
                    repository: repository,
                    name: name,
                    setCode: setCode,
                    collectorNumber: collectorNumber,
                    scannedImage: scannedImage
                )

                guard !Task.isCancelled else {
                    return
                }

                self.handleLookupResult(match)

            } catch {

                guard !Task.isCancelled else {
                    return
                }

                self.lastLookupKey = ""
                self.isLookingUp = false
                self.state = .error(error.localizedDescription)
            }
        }
    }

    nonisolated private static func resolveScanMatch(
        repository: CardRepository,
        name: String?,
        setCode: String?,
        collectorNumber: String?,
        scannedImage: UIImage?
    ) async throws -> ScanMatch {

        let cleanedName = name?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanedSet = setCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let cleanedCollector = collectorNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if
            let cleanedSet,
            !cleanedSet.isEmpty,
            let cleanedCollector,
            !cleanedCollector.isEmpty,
            let exact = try repository.card(
                set: cleanedSet,
                collectorNumber: cleanedCollector
            )
        {
            let evidence: ScanEvidence = if let cleanedName, !cleanedName.isEmpty,
                exact.name.caseInsensitiveCompare(cleanedName) == .orderedSame {
                .exactNameAndMetadata
            } else {
                .exactMetadata
            }

            return ScanMatch(
                candidates: [exact],
                selectedCard: exact,
                evidence: evidence
            )
        }

        guard let cleanedName, !cleanedName.isEmpty else {
            return ScanMatch(
                candidates: [],
                selectedCard: nil,
                evidence: .nameOnly
            )
        }

        let candidates = try lookupNameCandidates(
            repository: repository,
            name: cleanedName
        )

        guard candidates.count > 1, let scannedImage else {
            return ScanMatch(
                candidates: candidates,
                selectedCard: candidates.first,
                evidence: .nameOnly
            )
        }

        var visualMatch = await VisionFeaturePrintService.shared.confidentVisualMatch(
            scannedImage: scannedImage,
            candidates: candidates
        )

        if visualMatch == nil {
            visualMatch = await VisionFeaturePrintService.shared.closestVisualMatch(
                scannedImage: scannedImage,
                candidates: candidates
            )
        }

        guard
            let visualMatch,
            let artworkMatch = try artworkMatch(
                visualMatch: visualMatch,
                candidates: candidates,
                repository: repository
            )
        else {
            return ScanMatch(
                candidates: candidates,
                selectedCard: candidates.first,
                evidence: .nameOnly
            )
        }

        return artworkMatch
    }

    nonisolated private static func artworkMatch(
        visualMatch: VisionFeaturePrintService.VisualMatch,
        candidates: [MTGCard],
        repository: CardRepository
    ) throws -> ScanMatch? {

        guard
            let illustrationID = visualMatch.card.illustrationID?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !illustrationID.isEmpty
        else {
            return nil
        }

        let artworkPrintings = try repository.cards(
            illustrationID: illustrationID
        )
        .filter {
            $0.name.caseInsensitiveCompare(visualMatch.card.name) == .orderedSame
        }

        let narrowedCandidates = artworkPrintings.isEmpty ? [visualMatch.card] : artworkPrintings

        guard narrowedCandidates.count < candidates.count else {
            return nil
        }

        AppLog.debug(
            "[ScannerVM] Artwork narrowed printings:",
            candidates.count,
            "->",
            narrowedCandidates.count,
            visualMatch.card.set,
            visualMatch.card.collectorNumber,
            "distance:",
            visualMatch.distance
        )

        return ScanMatch(
            candidates: narrowedCandidates,
            selectedCard: visualMatch.card,
            evidence: .visualArtwork
        )
    }

    nonisolated private static func lookupNameCandidates(
        repository: CardRepository,
        name: String
    ) throws -> [MTGCard] {

        let results = try repository.search(
            query: name,
            filter: SearchFilter()
        )

        let exactNameMatches = results.filter {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }

        return exactNameMatches.isEmpty ? results : exactNameMatches
    }

    private func handleLookupResult(_ match: ScanMatch) {

        isLookingUp = false

        guard !match.candidates.isEmpty else {
            lastLookupKey = ""
            state = .scanning
            return
        }

        isScanning = false

        if match.shouldShowPrintingSelection {
            state = .selectPrinting(match.candidates)
        } else if let selectedCard = match.selectedCard ?? match.candidates.first {
            state = .found(selectedCard)
        } else {
            state = .scanning
        }
    }
}
