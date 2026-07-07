//
//  CollectionViewModel.swift
//  TcgScanner
//
//  Created by Joel James on 04/07/2026.
//

import Foundation
import Combine

final class CollectionViewModel {
    
    // MARK: - Published
    
    @Published private(set) var entries: [CollectionEntry] = []
    @Published private(set) var filteredEntries: [CollectionEntry] = []
    
    private var collectionCards: [CollectionCard] = []
    
    @Published var filter = SearchFilter() {
        didSet {
            applyFilters()
        }
    }
    
    
    @Published var searchText: String = "" {
        didSet {
            applyFilters()
        }
    }
    
    @Published var sortOption: SortOption = .name {
        didSet {
            applyFilters()
        }
    }
    
    // Placeholder for future filter chips
    @Published var showFoilsOnly = false {
        didSet {
            applyFilters()
        }
    }
    
    // MARK: - Private
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init() {
        
        loadCollection()
        
        NotificationCenter.default.publisher(
            for: .collectionDidChange
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.loadCollection()
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Public
    
    func refresh() {
        loadCollection()
        entries = CollectionStore.shared.entries
        applyFilters()
    }
    
    func updateFilter(_ filter: SearchFilter) {
        self.filter = filter
    }
    
    
    func delete(at indexPaths: [IndexPath]) {
        
        let ids = indexPaths.map { filteredEntries[$0.item].id }
        
        ids.forEach {
            CollectionStore.shared.remove(id: $0)
        }
        
        loadCollection()
    }
    
    var totalCards: Int {
        entries.reduce(0) { $0 + $1.count }
    }
    
    var uniqueCards: Int {
        entries.count
    }
    
    var totalValue: Double {
        
        entries.reduce(0) { total, entry in
            
            let price = Double(entry.usdPrice ?? "") ?? 0
            
            return total + (price * Double(entry.count))
        }
    }
    
    private func applyFilters() {

        // No collection
        guard !entries.isEmpty else {
            filteredEntries = []
            return
        }

        // Load every MTGCard for the collection in ONE database query
        let cards = CardDatabaseService.shared.cards(
            ids: entries.map(\.cardID)
        )

        // Build lookup dictionary
        let cardLookup = Dictionary(
            uniqueKeysWithValues: cards.map {
                ($0.id.lowercased(), $0)
            }
        )

        // Apply search/filter
        filteredEntries = entries.filter { entry in

            // If we can't find the card in the database,
            // keep it visible (important for imported custom cards)
            guard let card = cardLookup[entry.cardID.lowercased()] else {

                // Search still applies
                if !searchText.isEmpty &&
                    !entry.name.localizedCaseInsensitiveContains(searchText) {
                    return false
                }

                if showFoilsOnly && !entry.isFoil {
                    return false
                }

                return true
            }

            // Search
            if !searchText.isEmpty &&
                !card.name.localizedCaseInsensitiveContains(searchText) {
                return false
            }

            // Unified card filters
            guard CardFilterEngine.matches(card, filter: filter) else {
                return false
            }

            // Collection-only filters
            if showFoilsOnly && !entry.isFoil {
                return false
            }

            return true
        }

        sortEntries()
    }
    
    private func sortEntries() {

        switch sortOption {

        case .name:
            filteredEntries.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        case .recent:
            filteredEntries.sort {
                $0.dateAdded > $1.dateAdded
            }

        case .price:
            filteredEntries.sort {
                (Double($0.usdPrice ?? "0") ?? 0) >
                (Double($1.usdPrice ?? "0") ?? 0)
            }

        case .quantity:
            filteredEntries.sort {
                $0.count > $1.count
            }

        case .set:
            filteredEntries.sort {
                if $0.setCode == $1.setCode {
                    return $0.collectorNumber < $1.collectorNumber
                }
                return $0.setCode < $1.setCode
            }
        }
    }
}
// MARK: - Private

private extension CollectionViewModel {

    private func loadCollection() {

        entries = CollectionStore.shared.entries

        print("Entries:", entries.count)

        // Load only the cards that exist in the collection
        let cards = CardDatabaseService.shared.cards(
            ids: entries.map(\.cardID)
        )

        let cardsByID = Dictionary(
            uniqueKeysWithValues: cards.map {
                ($0.id.lowercased(), $0)
            }
        )

        collectionCards = entries.compactMap { entry in

            guard let card = cardsByID[entry.cardID.lowercased()] else {
                return nil
            }

            return CollectionCard(
                entry: entry,
                card: card
            )
        }

        print("CollectionCards:", collectionCards.count)

        applyFilters()
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
