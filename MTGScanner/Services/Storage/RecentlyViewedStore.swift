//
//  RecentlyViewedStore.swift
//  TcgScanner
//
//  Created by Joel James on 20/06/2026.
//
import Foundation

final class RecentlyViewedStore {

    static let shared = RecentlyViewedStore()

    private let key = "recently_viewed_cards"

    private init() {}

    var cards: [RecentCard] {

        guard
            let data = UserDefaults.standard.data(forKey: key),
            let cards = try? JSONDecoder().decode(
                [RecentCard].self,
                from: data
            )
        else {
            return []
        }

        return cards
    }

    func add(card: MTGCard) {

        var current = cards

        current.removeAll {
            $0.id == card.id
        }

        current.insert(
            RecentCard(card: card),
            at: 0
        )

        if current.count > 5 {
            current = Array(current.prefix(5))
        }

        save(current)
    }

    private func save(
        _ cards: [RecentCard]
    ) {

        guard let data =
            try? JSONEncoder().encode(cards)
        else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: key
        )
    }
}
