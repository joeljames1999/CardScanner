//
//  CollectionViewModel.swift
//  TcgScanner
//
//  Created by Joel James on 04/07/2026.
//

//
//  CollectionViewModel.swift
//  TcgScanner
//

import Foundation
import Combine

struct CollectionCard: Identifiable {

    let entry: CollectionEntry
    let card: MTGCard?

    var id: UUID {
        entry.id
    }
}

enum CollectionSortOption: String, CaseIterable {

    case name
    case set
    case price
    case quantity
    case dateAdded
}

@MainActor
final class CollectionViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var entries: [CollectionEntry] = []
    @Published private(set) var filteredEntries: [CollectionEntry] = []
    @Published private(set) var collectionCards: [CollectionCard] = []

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    @Published var searchText: String = "" {
        didSet {
            applyFilters()
        }
    }

    @Published var filter = SearchFilter() {
        didSet {
            applyFilters()
        }
    }

    @Published var sortOption: CollectionSortOption = .name {
        didSet {
            applyFilters()
        }
    }

    @Published var showFoilsOnly: Bool = false {
        didSet {
            applyFilters()
        }
    }

    // MARK: - Private

    private let repository: CardRepository
    private var loadTask: Task<Void, Never>?

    // MARK: - Init

    init(
        repository: CardRepository = AppDatabase.shared.cards
    ) {
        self.repository = repository
    }

    deinit {
        loadTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public

    func startObservingCollectionChanges() {

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(collectionDidChange),
            name: CollectionStore.didChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(collectionDidChange),
            name: .cardDatabaseDidChange,
            object: nil
        )
    }

    func card(
        for entry: CollectionEntry
    ) -> MTGCard? {

        collectionCards.first {
            $0.entry.id == entry.id
        }?.card
    }
    
    func loadCollection() {

        loadTask?.cancel()

        isLoading = true
        errorMessage = nil

        let savedEntries = CollectionStore.shared.entries
        entries = savedEntries

        collectionCards = savedEntries.map {
            CollectionCard(
                entry: $0,
                card: nil
            )
        }
        applyFilters()

        let ids = savedEntries.map(\.cardID)

        loadTask = Task { [repository] in

            do {

                let cardsByEntryID = try await Task.detached(
                    priority: .userInitiated
                ) {
                    let cards = try repository.cards(
                        ids: ids
                    )

                    var cardsByID: [String: MTGCard] = [:]
                    cardsByID.reserveCapacity(cards.count)

                    for card in cards {
                        cardsByID[card.id.lowercased()] = card
                    }

                    var resolvedCards: [UUID: MTGCard] = [:]
                    resolvedCards.reserveCapacity(savedEntries.count)

                    for entry in savedEntries {
                        if let card = cardsByID[entry.cardID.lowercased()] {
                            resolvedCards[entry.id] = card
                            continue
                        }

                        guard
                            !entry.name.isEmpty,
                            !entry.setCode.isEmpty,
                            !entry.collectorNumber.isEmpty,
                            let card = try repository.card(
                                name: entry.name,
                                set: entry.setCode,
                                collectorNumber: entry.collectorNumber
                            )
                        else {
                            continue
                        }

                        cardsByID[entry.cardID.lowercased()] = card
                        resolvedCards[entry.id] = card
                    }

                    return resolvedCards
                }.value

                guard !Task.isCancelled else {
                    return
                }

                let joined = savedEntries.map { entry in

                    CollectionCard(
                        entry: entry,
                        card: cardsByEntryID[entry.id]
                    )
                }

                self.collectionCards = joined
                self.isLoading = false
                self.applyFilters()

            } catch {

                guard !Task.isCancelled else {
                    return
                }

                self.collectionCards = []
                self.filteredEntries = savedEntries
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func refresh() {
        loadCollection()
    }

    func resetFilters() {
        filter.reset()
        showFoilsOnly = false
        searchText = ""
    }

    func updateFilter(
        _ newFilter: SearchFilter
    ) {
        filter = newFilter
    }

    func updateFoilsOnly(
        _ showFoilsOnly: Bool
    ) {
        self.showFoilsOnly = showFoilsOnly
    }

    func updateSort(
        _ option: CollectionSortOption
    ) {
        sortOption = option
    }

    // MARK: - Filtering

    private func applyFilters() {

        var cards = collectionCards

        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if !query.isEmpty {

            cards = cards.filter { item in

                item.entry.name.lowercased().contains(query) ||
                item.entry.setCode.lowercased().contains(query) ||
                item.entry.setName.lowercased().contains(query) ||
                item.entry.collectorNumber.lowercased().contains(query) ||
                item.card?.name.lowercased().contains(query) == true ||
                item.card?.typeLine.lowercased().contains(query) == true
            }
        }

        if showFoilsOnly {
            cards.removeAll {
                !$0.entry.isFoil
            }
        }

        if filter.hasActiveFilters {
            cards = cards.filter {
                guard let card = $0.card else {
                    return false
                }

                return CardFilterEngine.matches(
                    card,
                    filter: filter
                )
            }
        }

        cards = sort(cards)

        filteredEntries = cards.map(\.entry)
    }

    private func sort(
        _ cards: [CollectionCard]
    ) -> [CollectionCard] {

        switch sortOption {

        case .name:
            return cards.sorted {
                $0.entry.name.localizedCaseInsensitiveCompare(
                    $1.entry.name
                ) == .orderedAscending
            }

        case .set:
            return cards.sorted {

                if $0.entry.setName == $1.entry.setName {
                    return $0.entry.collectorNumber < $1.entry.collectorNumber
                }

                return $0.entry.setName.localizedCaseInsensitiveCompare(
                    $1.entry.setName
                ) == .orderedAscending
            }

        case .price:
            return cards.sorted {
                $0.entry.priceValue > $1.entry.priceValue
            }

        case .quantity:
            return cards.sorted {
                $0.entry.count > $1.entry.count
            }

        case .dateAdded:
            return cards.sorted {
                $0.entry.dateAdded > $1.entry.dateAdded
            }
        }
    }

    // MARK: - Stats

    var activeFilterCount: Int {
        filter.activeFilterCount + (showFoilsOnly ? 1 : 0)
    }

    var totalCards: Int {
        filteredEntries.reduce(0) {
            $0 + $1.count
        }
    }

    var collectionTotalCards: Int {
        entries.reduce(0) {
            $0 + $1.count
        }
    }

    var estimatedValue: Double {
        filteredEntries.reduce(0) {
            $0 + ($1.priceValue * Double($1.count))
        }
    }

    var collectionEstimatedValue: Double {
        entries.reduce(0) {
            $0 + ($1.priceValue * Double($1.count))
        }
    }

    var totalValue: Double {
        estimatedValue
    }

    var isEmpty: Bool {
        entries.isEmpty
    }

    var isFilteredEmpty: Bool {
        !entries.isEmpty && filteredEntries.isEmpty
    }

    // MARK: - Notifications

    @objc private func collectionDidChange() {
        loadCollection()
    }
}

// MARK: - Sort Option

extension CollectionViewModel {

    enum SortOption: String, CaseIterable {

        case name

        case recent

        case price

        case quantity

        case set

        var title: String {

            switch self {

            case .name:
                return "Name"

            case .recent:
                return "Recently Added"

            case .price:
                return "Price"

            case .quantity:
                return "Quantity"

            case .set:
                return "Set"
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {

    static let collectionDidChange = Notification.Name("collectionDidChange")
}
