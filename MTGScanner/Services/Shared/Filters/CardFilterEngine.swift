//
//  CardFilterEngine.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

enum CardFilterEngine {

    static func filter(
        _ cards: [MTGCard],
        using filter: SearchFilter
    ) -> [MTGCard] {

        var results = cards

        results = applyLegalFilter(
            results,
            filter: filter
        )

        results = applyColourFilter(
            results,
            filter: filter
        )

        results = applyFormatFilter(
            results,
            filter: filter
        )

        results = applyPrintingGrouping(
            results,
            filter: filter
        )

        return results
    }
}

private extension CardFilterEngine {

    static func applyLegalFilter(
        _ cards: [MTGCard],
        filter: SearchFilter
    ) -> [MTGCard] {

        guard filter.legalCardsOnly else {
            return cards
        }

        return cards.filter {

            let layout = $0.cardLayout?.lowercased() ?? ""
            let type = $0.typeLine.lowercased()
            let set = $0.setName.lowercased()

            if [
                "token",
                "emblem",
                "art_series",
                "planar",
                "scheme",
                "vanguard",
                "double_faced_token",
                "playtest"
            ].contains(layout) {

                return false
            }

            if type.contains("token") {
                return false
            }

            if set.contains("tokens") {
                return false
            }

            if set.contains("playtest") {
                return false
            }

            return $0.legalities?.isLegalSomewhere ?? false
        }
    }
}

private extension CardFilterEngine {

    static func applyColourFilter(
        _ cards: [MTGCard],
        filter: SearchFilter
    ) -> [MTGCard] {

        guard !filter.selectedManaColors.isEmpty else {
            return cards
        }

        return cards.filter {

            let colours = SearchFilter.extractManaColors(
                from: $0.colors
            )

            return SearchFilter.cardColorsMatch(
                colours,
                selectedColors: filter.selectedManaColors,
                mode: filter.colorFilterMode
            )
        }
    }
}

private extension CardFilterEngine {

    static func applyFormatFilter(
        _ cards: [MTGCard],
        filter: SearchFilter
    ) -> [MTGCard] {

        guard !filter.selectedFormats.isEmpty else {
            return cards
        }

        return cards.filter {

            guard let legalities = $0.legalities else {
                return false
            }

            return filter.selectedFormats.contains {

                legalities.isLegal(in: $0)
            }
        }
    }
}

private extension CardFilterEngine {

    static func applyPrintingGrouping(
        _ cards: [MTGCard],
        filter: SearchFilter
    ) -> [MTGCard] {

        guard filter.groupPrintings else {
            return cards
        }

        var seen = Set<String>()
        var grouped: [MTGCard] = []

        for card in cards {

            let key = card.name.lowercased()

            guard seen.insert(key).inserted else {
                continue
            }

            grouped.append(card)
        }

        return grouped
    }
}

extension CardFilterEngine {
    static func matches(
        _ card: MTGCard,
        filter: SearchFilter
    ) -> Bool {

        // Rarity
        if !filter.selectedRarities.isEmpty &&
            !filter.selectedRarities.contains(card.rarity) {
            return false
        }

        // Set
        if !filter.selectedSets.isEmpty &&
            !filter.selectedSets.contains(card.set.uppercased()) {
            return false
        }

        // Mana Value
        if !filter.selectedManaCosts.isEmpty {

            let bucket = SearchFilter.manaCostBucket(for: card.cmc)

            if !filter.selectedManaCosts.contains(bucket) {
                return false
            }
        }

        // Colours
        if !filter.selectedManaColors.isEmpty {

            let colours = SearchFilter.extractManaColors(
                from: card.colors
            )

            if !SearchFilter.cardColorsMatch(
                colours,
                selectedColors: filter.selectedManaColors,
                mode: filter.colorFilterMode
            ) {
                return false
            }
        }

        return true
    }
}
