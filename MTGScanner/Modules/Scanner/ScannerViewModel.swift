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
        print("Cards:", CardDatabaseService.shared.isEmpty)
        print("Hashes:", CardDatabaseService.shared.artHashCount)
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
        
        Task {
            try? await Task.sleep(for: .seconds(2))
            lastAcceptedCardID = nil
        }
    }

    func processCardImage(
        _ image: UIImage,
        recognisedName: String?
    ) {

        guard isScanning else {
            return
        }

        guard case .scanning = state else {
            return
        }

        if let recognisedName,
           recognisedName.count > 2 {

            print("[Scanner] OCR found: \(recognisedName)")

            let matches =
                CardDatabaseService.shared.findCards(
                    fuzzyName: recognisedName
                )

            print("[Scanner] OCR matches: \(matches.count)")

            if matches.count == 1 {

                let card = matches[0]

                SessionStore.shared.addOrIncrement(
                    card: card
                )

                state = .found(card)
                return
            }

            if matches.count > 1 {

                state = .selectPrinting(matches)
                return
            }
        }

        print("[Scanner] OCR failed, falling back to artwork")

        lookupTask?.cancel()

        lookupTask = Task {
            await matchByArt(
                image,
                recognisedName: recognisedName
            )
        }
    }

    // MARK: - Art Matching

    private func matchByArt(
        _ image: UIImage,
        recognisedName: String? = nil
    ) async {

        guard let artCrop = ArtHashService.shared.cropArtRegion(from: image),
              let liveHash = ArtHashService.shared.pHash(of: artCrop)
        else {
            print("[Scanner] ❌ pHash failed")
            return
        }

        let candidates =
            CardDatabaseService.shared
                .findCardCandidatesByArtHash(
                    liveHash,
                    limit: 20
                )

        guard !candidates.isEmpty else {
            state = .error("Card not recognised")
            return
        }

        print("[Scanner] Top candidates:")

        for candidate in candidates.prefix(5) {
            print(
                "[Scanner]",
                candidate.card.name,
                "distance:",
                candidate.distance
            )
        }

        // OCR + Art combined
        if let recognisedName,
           !recognisedName.isEmpty {

            let fuzzyName =
                recognisedName
                    .lowercased()
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

            if let ocrMatch = candidates.first(where: {

                let candidateName =
                    $0.card.name.lowercased()

                return candidateName.contains(fuzzyName)
                    || fuzzyName.contains(candidateName)

            }) {

                print(
                    "[Scanner] ✅ OCR + Art:",
                    ocrMatch.card.name
                )

                handleMatchedCard(ocrMatch.card)
                return
            }
        }

        let best = candidates[0]

        print(
            "[Scanner] Best art match:",
            best.card.name,
            "distance:",
            best.distance
        )

        // Very confident
        if best.distance <= 6 {

            handleMatchedCard(best.card)
            return
        }

        // Reasonably confident
        if best.distance <= 10 {

            let printings =
                CardDatabaseService.shared
                    .allPrintings(
                        named: best.card.name
                    )

            if printings.count <= 1 {

                handleMatchedCard(best.card)

            } else {

                state = .selectPrinting(printings)
            }

            return
        }

        state = .error(
            "Could not confidently identify card"
        )
    }

    // MARK: - Art Hash Caching

    private func handleMatchedCard(
        _ card: MTGCard
    ) {

        guard card.name != lastFoundCardName else {
            return
        }

        lastFoundCardName = card.name

        let printings =
            CardDatabaseService.shared
                .allPrintings(
                    named: card.name
                )

        if printings.count <= 1 {

            SessionStore.shared
                .addOrIncrement(card: card)

            state = .found(card)

        } else {

            state = .selectPrinting(printings)
        }
    }
    
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
