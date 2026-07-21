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

        guard let name = result.cardName else {
            return
        }

        lookupCard(
            name: name,
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
        name: String,
        setCode: String?,
        collectorNumber: String?,
        scannedImage: UIImage?
    ) {

        let lookupKey = [
            name,
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

                let candidates = try await Task.detached(
                    priority: .userInitiated
                ) {
                    try Self.lookupCandidates(
                        repository: repository,
                        name: name,
                        setCode: setCode,
                        collectorNumber: collectorNumber
                    )
                }.value

                guard !Task.isCancelled else {
                    return
                }

                let narrowedCandidates = try await Self.narrowCandidatesByArtwork(
                    scannedImage: scannedImage,
                    candidates: candidates,
                    repository: repository
                )

                guard !Task.isCancelled else {
                    return
                }

                self.handleLookupResult(
                    narrowedCandidates,
                    fallbackName: name,
                    preferPrintingSelection: candidates.count > 1
                )

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

    nonisolated private static func lookupCandidates(
        repository: CardRepository,
        name: String,
        setCode: String?,
        collectorNumber: String?
    ) throws -> [MTGCard] {

        let cleanedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

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
                name: cleanedName,
                set: cleanedSet,
                collectorNumber: cleanedCollector
            )
        {
            return [exact]
        }

        let results = try repository.search(
            query: cleanedName,
            filter: SearchFilter()
        )

        let exactNameMatches = results.filter {
            $0.name.caseInsensitiveCompare(cleanedName) == .orderedSame
        }

        return exactNameMatches.isEmpty ? results : exactNameMatches
    }

    nonisolated private static func narrowCandidatesByArtwork(
        scannedImage: UIImage?,
        candidates: [MTGCard],
        repository: CardRepository
    ) async throws -> [MTGCard] {

        guard candidates.count > 1, let scannedImage else {
            return candidates
        }

        guard
            let visualMatch = await VisionFeaturePrintService.shared.bestVisualMatch(
                scannedImage: scannedImage,
                candidates: candidates
            ),
            let illustrationID = visualMatch.illustrationID?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !illustrationID.isEmpty
        else {
            return candidates
        }

        let artworkPrintings = try repository.cards(
            illustrationID: illustrationID
        )
        .filter {
            $0.name.caseInsensitiveCompare(visualMatch.name) == .orderedSame
        }

        AppLog.debug(
            "[ScannerVM] Artwork narrowed printings:",
            candidates.count,
            "->",
            artworkPrintings.count,
            visualMatch.set,
            visualMatch.collectorNumber
        )

        return artworkPrintings.isEmpty ? [visualMatch] : artworkPrintings
    }

    private func handleLookupResult(
        _ candidates: [MTGCard],
        fallbackName: String,
        preferPrintingSelection: Bool
    ) {

        isLookingUp = false

        guard !candidates.isEmpty else {
            lastLookupKey = ""
            state = .scanning
            return
        }

        isScanning = false

        if candidates.count == 1, !preferPrintingSelection {
            state = .found(candidates[0])
        } else {
            state = .selectPrinting(candidates)
        }
    }
}
