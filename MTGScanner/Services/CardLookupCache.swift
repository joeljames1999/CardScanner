//
//  CardLookupCache.swift
//  TcgScanner
//
//  Created by Joel James on 03/07/2026.
//

import Foundation

final class CardLookupCache {

    static let shared = CardLookupCache()

    private var lookup: [String: MTGCard] = [:]

    private init() {}

    func build() {

        if !lookup.isEmpty {
            return
        }

        let cards = CardDatabaseService.shared.allCards()

        lookup.reserveCapacity(cards.count)

        for card in cards {

            let key =
                "\(card.name.lowercased())|" +
                "\(card.set.lowercased())|" +
                "\(card.collectorNumber)"

            lookup[key] = card
        }

        print("[CSV] Cached \(lookup.count) cards")
    }

    func card(
        name: String,
        set: String,
        collector: String
    ) -> MTGCard? {

        lookup[
            "\(name.lowercased())|\(set.lowercased())|\(collector)"
        ]
    }
}
