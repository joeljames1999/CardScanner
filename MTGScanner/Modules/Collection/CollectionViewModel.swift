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
}

// MARK: - Private

private extension CollectionViewModel {

    func loadCollection() {

        entries = CollectionStore.shared.entries

        applyFilters()
    }

    func applyFilters() {

        var results = entries

        // Search

        if !searchText.isEmpty {

            let query = searchText.lowercased()

            results = results.filter {

                $0.name.lowercased().contains(query) ||
                $0.setCode.lowercased().contains(query) ||
                $0.collectorNumber.lowercased().contains(query)
            }
        }

        // Future filter

        if showFoilsOnly {

            results = results.filter {
                $0.isFoil
            }
        }

        // Sort

        switch sortOption {

        case .name:

            results.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        case .price:

            results.sort {

                let lhs = Double($0.usdPrice ?? "") ?? 0
                let rhs = Double($1.usdPrice ?? "") ?? 0

                return lhs > rhs
            }

        case .set:

            results.sort {

                if $0.setCode == $1.setCode {

                    return $0.collectorNumber.localizedStandardCompare($1.collectorNumber) == .orderedAscending
                }

                return $0.setCode < $1.setCode
            }

        case .recent:

            results.sort {
                $0.dateAdded > $1.dateAdded
            }

        case .quantity:

            results.sort {
                $0.count > $1.count
            }
        }

        filteredEntries = results
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
