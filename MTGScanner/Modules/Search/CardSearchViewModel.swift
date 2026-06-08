import Foundation
import Combine

@MainActor
final class CardSearchViewModel: ObservableObject {

    @Published var searchText = ""
    @Published var filter = SearchFilter()
    @Published private(set) var cards: [MTGCard] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Combine searchText and filter changes
        Publishers.CombineLatest(
            $searchText.debounce(for: .milliseconds(250), scheduler: RunLoop.main),
            $filter
        )
        .removeDuplicates { prev, curr in
            prev.0 == curr.0 && prev.1 == curr.1
        }
        .sink { [weak self] searchText, filter in
            guard let self else { return }
            self.performSearch(query: searchText, filter: filter)
        }
        .store(in: &cancellables)
    }

    // MARK: - Search

    private func performSearch(query: String, filter: SearchFilter) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty && !filter.hasActiveFilters {
            cards = []
            return
        }
        
        Task.detached {

            let results =
                CardDatabaseService.shared.searchCards(
                    query: query,
                    filter: filter
                )

            await MainActor.run {
                self.cards = results
            }
        }
    }

    // MARK: - Filter Management

    func updateFilter(_ newFilter: SearchFilter) {
        filter = newFilter
    }

    func resetFilter() {
        filter.reset()
    }
}
