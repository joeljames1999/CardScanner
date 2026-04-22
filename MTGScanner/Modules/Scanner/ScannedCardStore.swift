import Foundation
import Combine

final class ScannedCardStore: ObservableObject {

    @Published private(set) var scannedCards: [MTGCard] = []

    // MARK: - Add

    func add(_ card: MTGCard) {
        // Prevent duplicates
        guard !scannedCards.contains(where: { $0.id == card.id }) else { return }
        scannedCards.append(card)
    }

    func addIfNew(_ card: MTGCard) {
        add(card)
    }

    // MARK: - Remove

    func remove(at index: Int) {
        guard scannedCards.indices.contains(index) else { return }
        scannedCards.remove(at: index)
    }

    func remove(card: MTGCard) {
        scannedCards.removeAll { $0.id == card.id }
    }

    // MARK: - Reset

    func clear() {
        scannedCards.removeAll()
    }

    // MARK: - Commit helper

    func drain() -> [MTGCard] {
        let cards = scannedCards
        scannedCards.removeAll()
        return cards
    }
}
