import Foundation
import Combine

@MainActor
final class CardSearchViewModel: ObservableObject {

    @Published var searchText = ""
    @Published var filter = SearchFilter()

    @Published private(set) var cards: [MTGCard] = []

    private var cancellables = Set<AnyCancellable>()

    init() {

        Publishers.CombineLatest(
            $searchText
                .debounce(
                    for: .milliseconds(250),
                    scheduler: RunLoop.main
                )
                .removeDuplicates(),
            $filter.removeDuplicates()
        )
        .sink { [weak self] searchText, filter in

            guard let self else { return }

            self.reloadCards(
                searchText: searchText,
                filter: filter
            )
        }
        .store(in: &cancellables)
    }

    func updateFilter(_ filter: SearchFilter) {
        self.filter = filter
    }

    func resetFilter() {
        filter.reset()
    }
}

private extension CardSearchViewModel {

    func reloadCards(
        searchText: String,
        filter: SearchFilter
    ) {

        cards = CardDatabaseService.shared.searchCards(
            query: searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            filter: filter
        )
    }
}
