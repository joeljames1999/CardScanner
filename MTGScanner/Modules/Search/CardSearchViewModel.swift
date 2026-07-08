//
//  SearchViewModel.swift
//  TcgScanner
//

import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var results: [MTGCard] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    @Published var searchText: String = "" {
        didSet {
            scheduleSearch()
        }
    }

    @Published var filter = SearchFilter() {
        didSet {
            scheduleSearch()
        }
    }

    // MARK: - Private

    private let repository: CardRepository
    private var searchTask: Task<Void, Never>?

    // MARK: - Init

    init(
        repository: CardRepository = AppDatabase.shared.cards
    ) {
        self.repository = repository
    }

    deinit {
        searchTask?.cancel()
    }

    // MARK: - Public

    func refresh() {
        scheduleSearch()
    }

    func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        results = []
        errorMessage = nil
        isLoading = false
    }

    func resetFilters() {
        filter.reset()
    }

    func updateFilter(_ newFilter: SearchFilter) {
        filter = newFilter
    }

    // MARK: - Search

    private func scheduleSearch() {

        searchTask?.cancel()

        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let currentFilter = filter

        guard !query.isEmpty || currentFilter.hasActiveFilters else {
            results = []
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        searchTask = Task { [repository] in

            try? await Task.sleep(
                nanoseconds: 250_000_000
            )

            guard !Task.isCancelled else {
                return
            }

            do {

                let cards = try await Task.detached(
                    priority: .userInitiated
                ) {
                    try repository.search(
                        query: query,
                        filter: currentFilter
                    )
                }.value

                guard !Task.isCancelled else {
                    return
                }

                self.results = cards
                self.isLoading = false

            } catch {

                guard !Task.isCancelled else {
                    return
                }

                self.results = []
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
