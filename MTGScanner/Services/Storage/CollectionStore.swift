import Foundation

// MARK: - Collection Store

@MainActor
final class CollectionStore {

    static let shared = CollectionStore()

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("collection.json")
    }()

    private(set) var entries: [CollectionEntry] = []

    static let didChangeNotification = Notification.Name("CollectionStoreDidChange")

    enum SortKey { case name, set, price, date }

    private init() { load() }

    // MARK: - Query

    var totalCards: Int { entries.reduce(0) { $0 + $1.count } }

    var estimatedValue: Double {
        entries.reduce(0) { $0 + ($1.priceValue * Double($1.count)) }
    }

    func entry(for cardID: String) -> CollectionEntry? {
        entries.first { $0.cardID == cardID }
    }

    func contains(cardID: String) -> Bool {
        entries.contains { $0.cardID == cardID }
    }

    // MARK: - Sorting

    func sort(by key: SortKey) {
        switch key {
        case .name:  entries.sort { $0.name < $1.name }
        case .set:   entries.sort { $0.setName < $1.setName }
        case .price: entries.sort { $0.priceValue > $1.priceValue }
        case .date:  entries.sort { $0.dateAdded > $1.dateAdded }
        }
        save()
        notifyChange()
    }

    // MARK: - Mutations

    func addSessionEntries(
        _ sessionEntries: [SessionEntry]
    ) {

        for session in sessionEntries {

            let card = session.card

            if let idx = entries.firstIndex(where: {

                $0.cardID == card.id &&
                $0.condition == session.condition &&
                $0.resolvedFinish == session.finish &&
                $0.isAltered == session.isAltered &&
                $0.language == session.language

            }) {

                entries[idx].count += session.count

            } else {

                entries.insert(
                    CollectionEntry(
                        from: card,
                        count: session.count,
                        condition: session.condition,
                        isFoil: session.isFoil,
                        finish: session.finish,
                        isAltered: session.isAltered,
                        language: session.language
                    ),
                    at: 0
                )
            }
        }

        save()
        notifyChange()
    }

    func updateCount(id: UUID, count: Int, notify: Bool = true) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        if count <= 0 {
            entries.remove(at: idx)
        } else {
            entries[idx].count = count
        }
        save()
        if notify { notifyChange() }
    }

    func updateCondition(id: UUID, condition: CardCondition, notify: Bool = true) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].condition = condition
        save()
        if notify { notifyChange() }
    }

    func updateFinish(id: UUID, finish: CardFinish, notify: Bool = true) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].finish = finish
        entries[idx].isFoil = finish.isFoilLike
        save()
        if notify { notifyChange() }
    }

    func updatePrinting(id: UUID, card: MTGCard, notify: Bool = true) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }

        let current = entries[idx]
        let availableFinishes = card.availableFinishes
        let preservedFinish = availableFinishes.contains(current.resolvedFinish)
            ? current.resolvedFinish
            : availableFinishes.first ?? current.resolvedFinish

        entries[idx] = CollectionEntry(
            id: current.id,
            count: current.count,
            cardID: card.id,
            name: card.name,
            setCode: card.set,
            setName: card.setName,
            collectorNumber: card.collectorNumber,
            rarity: card.rarity,
            condition: current.condition,
            isFoil: preservedFinish.isFoilLike,
            finish: preservedFinish,
            isAltered: current.isAltered,
            language: current.language,
            purchasePrice: card.prices?.usd.flatMap(Double.init),
            usdPrice: card.prices?.usd,
            imageURL: card.displayImage,
            dateAdded: current.dateAdded
        )

        save()
        if notify { notifyChange() }
    }

    func remove(id: UUID, notify: Bool = true) {
        entries.removeAll { $0.id == id }
        save()
        if notify { notifyChange() }
    }

    func removeAll() {
        entries = []
        save()
        notifyChange()
    }

    func publishChanges() {
        notifyChange()
    }

    // MARK: - Import / Merge

    func merge(_ imported: [CollectionEntry]) {
        for entry in imported {
            if let idx = entries.firstIndex(where: {
                $0.name.lowercased() == entry.name.lowercased() &&
                $0.setCode.lowercased() == entry.setCode.lowercased() &&
                $0.collectorNumber == entry.collectorNumber &&
                $0.condition == entry.condition &&
                $0.resolvedFinish == entry.resolvedFinish &&
                $0.language == entry.language
            }) {
                entries[idx].count += entry.count
                entries[idx].cardID = entry.cardID
                entries[idx].setName = entry.setName
                entries[idx].rarity = entry.rarity
                entries[idx].purchasePrice = entry.purchasePrice ?? entries[idx].purchasePrice
                entries[idx].usdPrice = entry.usdPrice ?? entries[idx].usdPrice
                entries[idx].imageURL = entry.imageURL ?? entries[idx].imageURL
            } else {
                entries.append(entry)
            }
        }
        save()
        notifyChange()
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomicWrite)
        } catch {
            print("[CollectionStore] Save error: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data    = try Data(contentsOf: fileURL)
            entries     = try JSONDecoder().decode([CollectionEntry].self, from: data)
        } catch {
            print("[CollectionStore] Load error: \(error)")
        }
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: CollectionStore.didChangeNotification, object: nil)
    }
}

// MARK: - Helpers

extension CollectionEntry {
    var priceValue: Double {
        usdPrice.flatMap(Double.init) ?? purchasePrice ?? 0
    }

    var resolvedFinish: CardFinish {
        finish ?? (isFoil ? .foil : .nonfoil)
    }
}
