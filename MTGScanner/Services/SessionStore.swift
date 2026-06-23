import Foundation
import Combine

// MARK: - Session Store
// Holds cards scanned in the current session. In-memory only — not persisted.
// The user reviews this list before committing to the main collection.

final class SessionStore: ObservableObject {

    static let shared = SessionStore()

    @Published private(set) var entries: [SessionEntry] = []

    private init() {}

    // MARK: - Query

    var isEmpty: Bool { entries.isEmpty }
    var totalCards: Int { entries.reduce(0) { $0 + $1.count } }

    func contains(cardID: String) -> Bool {
        entries.contains { $0.card.id == cardID }
    }

    // MARK: - Mutations

    func addOrIncrement(card: MTGCard) {
        if let idx = entries.firstIndex(where: { $0.card.id == card.id }) {
            entries[idx].count += 1
        } else {
            entries.insert(SessionEntry(card: card), at: 0)
        }
    }
    
    func add(_ entry: SessionEntry) {

        if let idx = entries.firstIndex(where: {

            $0.card.id == entry.card.id &&
            $0.language == entry.language &&
            $0.isFoil == entry.isFoil &&
            $0.condition == entry.condition

        }) {

            entries[idx].count += entry.count

        } else {

            entries.insert(entry, at: 0)
        }
    }
    

    func setCount(id: UUID, count: Int) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        if count <= 0 {
            entries.remove(at: idx)
        } else {
            entries[idx].count = count
        }
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    func clear() {
        entries = []
    }
}
