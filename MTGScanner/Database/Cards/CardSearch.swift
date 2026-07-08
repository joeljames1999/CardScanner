//
//  CardSearch.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

enum CardSearch {

    static func search(
        query: String,
        filter: SearchFilter,
        database: Database
    ) throws -> [MTGCard] {

        let search = SearchQueryBuilder.build(
            query: query,
            filter: filter
        )

        let statement = try database.prepare(
            search.sql
        )

        defer {
            statement.finalize()
        }

        for (index, parameter) in search.parameters.enumerated() {

            try statement.bind(
                parameter,
                at: index + 1
            )
        }

        var cards: [MTGCard] = []

        while statement.step() {

            cards.append(
                try CardRowMapper.map(statement)
            )
        }

        // SQL can't efficiently perform an exact colour comparison.
        // Apply that final refinement in Swift.

        if filter.colorFilterMode == .includesOnlyThese &&
            !filter.selectedManaColors.isEmpty {

            cards = cards.filter {

                let colours =
                    SearchFilter.extractManaColors(
                        from: $0.colors
                    )

                return SearchFilter.cardColorsMatch(
                    colours,
                    selectedColors: filter.selectedManaColors,
                    mode: filter.colorFilterMode
                )
            }
        }

        return cards
    }
}
