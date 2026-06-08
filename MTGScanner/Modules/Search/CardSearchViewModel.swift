import Foundation
import Combine

@MainActor
final class CardSearchViewModel: ObservableObject {

    @Published var searchText = ""
    @Published var filter = SearchFilter()
    @Published private(set) var cards: [MTGCard] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Combine search text and filter changes
        Publishers.CombineLatest(
            $searchText
                .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
                .removeDuplicates(),
            $filter
                .removeDuplicates()
        )
        .sink { [weak self] (searchText, filter) in
            guard let self else { return }
            
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Call the unified searchCards method with BOTH query and filter
            self.cards = CardDatabaseService.shared.searchCards(query: trimmed, filter: filter)
            
            print("[Search] Results: \(self.cards.count) cards")
            print("[Search] Filter active: \(filter.hasActiveFilters)")
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Filter Management
    
    func updateFilter(_ newFilter: SearchFilter) {
        self.filter = newFilter
    }
    
    func resetFilter() {
        self.filter = SearchFilter()
    }
}
