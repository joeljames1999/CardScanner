//
//  CardLookupCache.swift
//  TcgScanner
//
//  Created by Joel James on 03/07/2026.
//

import Foundation

final class CardLookupCache {

    static let shared = CardLookupCache()

    private init() {}

    private var cardsByID: [String: MTGCard] = [:]
    private var cardsByKey: [String: MTGCard] = [:]

    // MARK: - Build

    func build(with cards: [MTGCard]) {

        cardsByID.removeAll(keepingCapacity: true)
        cardsByKey.removeAll(keepingCapacity: true)

        cardsByID.reserveCapacity(cards.count)
        cardsByKey.reserveCapacity(cards.count)

        for card in cards {

            cardsByID[card.id.lowercased()] = card

            let key = makeKey(
                name: card.name,
                set: card.set,
                collector: card.collectorNumber
            )

            cardsByKey[key] = card
        }

        print("[CardLookupCache] Cached \(cards.count) cards")
    }

    func clear() {

        cardsByID.removeAll()
        cardsByKey.removeAll()
    }

    // MARK: - Lookup

    func card(id: String) -> MTGCard? {

        cardsByID[id.lowercased()]
    }

    func card(
        name: String,
        set: String,
        collector: String
    ) -> MTGCard? {

        cardsByKey[
            makeKey(
                name: name,
                set: set,
                collector: collector
            )
        ]
    }

    // MARK: - Helpers

    private func makeKey(
        name: String,
        set: String,
        collector: String
    ) -> String {

        "\(name.lowercased())|\(set.lowercased())|\(collector)"
    }
}
