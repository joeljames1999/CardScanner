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

    static func == (lhs: ScannerState, rhs: ScannerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.scanning, .scanning): return true
        case (.found(let a), .found(let b)):         return a.id == b.id
        case (.selectPrinting(let a), .selectPrinting(let b)): return a.map(\.id) == b.map(\.id)
        case (.error(let a), .error(let b)):         return a == b
        default: return false
        }
    }
}

// MARK: - ScannerViewModel

@MainActor
final class ScannerViewModel: ObservableObject {

    @Published private(set) var state: ScannerState = .idle
    @Published var isScanning: Bool = false
    @Published private(set) var hashIndexCount: Int = 0

    private let scryfallService = ScryfallService()
    private var lookupTask: Task<Void, Never>?
    private var lastFoundCardName: String = ""

    // MARK: - Public

    func startScanning() {
        isScanning = true
        state = .scanning
        lastFoundCardName = ""
        hashIndexCount = CardDatabaseService.shared.artHashCount
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
    }

    func processCardImage(_ image: UIImage) {
        guard isScanning else { return }
        guard case .scanning = state else { return }

        lookupTask?.cancel()
        lookupTask = Task {
            await matchByArt(image)
        }
    }

    // MARK: - Art Matching

    private func matchByArt(_ image: UIImage) async {
        guard let artCrop  = ArtHashService.shared.cropArtRegion(from: image),
              let liveHash = ArtHashService.shared.pHash(of: artCrop)
        else {
            print("[Scanner] ❌ pHash failed")
            return
        }

        let indexSize = CardDatabaseService.shared.artHashCount
        print("[Scanner] 🔍 Index: \(indexSize) | hash: \(liveHash)")

        guard indexSize > 0 else {
            state = .error("Building card index, please wait…")
            return
        }

        guard let match = CardDatabaseService.shared.findCardByArtHash(liveHash) else {
            print("[Scanner] ❌ No match")
            return
        }

        print("[Scanner] ✅ \(match.card.name) distance=\(match.distance)")
        guard !Task.isCancelled else { return }
        guard match.card.name != lastFoundCardName else { return }

        lastFoundCardName = match.card.name

        // Fetch ALL printings of this card name, newest first
        let allPrintings = CardDatabaseService.shared.allPrintings(named: match.card.name)
        print("[Scanner] Found \(allPrintings.count) printings for \(match.card.name)")

        if allPrintings.count <= 1 {
            // Only one printing — add directly, no picker needed
            SessionStore.shared.addOrIncrement(card: match.card)
            state = .found(match.card)
        } else {
            // Multiple printings — show set picker
            state = .selectPrinting(allPrintings)
        }

        Task { await cacheArtHashIfNeeded(for: match.card) }

        // Failsafe — reset if user ignores the picker for 30s
        try? await Task.sleep(nanoseconds: 30_000_000_000)
        guard !Task.isCancelled else { return }
        if case .selectPrinting = state {
            resetToScanning()
        }
    }

    // MARK: - Art Hash Caching

    func cacheArtHashIfNeeded(for card: MTGCard, hash: UInt64? = nil) async {
        guard !CardDatabaseService.shared.hasArtHash(cardId: card.id) else { return }

        if let hash = hash {
            CardDatabaseService.shared.storeArtHash(cardId: card.id, hash: hash)
            hashIndexCount = CardDatabaseService.shared.artHashCount
            return
        }

        guard let url = card.imageUris?.artCrop ?? card.imageUris?.normal else { return }
        if let hash = await ArtHashService.shared.downloadAndHash(imageURL: url) {
            CardDatabaseService.shared.storeArtHash(cardId: card.id, hash: hash)
            hashIndexCount = CardDatabaseService.shared.artHashCount
            print("[Scanner] Cached hash for \(card.name) — index: \(CardDatabaseService.shared.artHashCount)")
        }
    }
}
