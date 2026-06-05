//
//  CardSearchViewModel.swift
//  TcgScanner
//
//  Created by Joel James on 04/06/2026.
//

import Foundation
import Combine

@MainActor
final class CardSearchViewModel: ObservableObject {

    @Published var searchText = ""
    @Published private(set) var cards: [MTGCard] = []

    private var cancellables = Set<AnyCancellable>()

    init() {

        $searchText
            .debounce(
                for: .milliseconds(250),
                scheduler: RunLoop.main
            )
            .removeDuplicates()
            .sink { [weak self] text in

                guard let self else { return }

                self.cards =
                    CardDatabaseService.shared
                        .searchCards(query: text)
            }
            .store(in: &cancellables)
    }
}
