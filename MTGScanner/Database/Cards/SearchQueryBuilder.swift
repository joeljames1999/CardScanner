//
//  SearchQueryBuilder.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

struct SearchQuery {

    let sql: String
    let parameters: [Any]
}

enum SearchQueryBuilder {

    static func build(
        query: String,
        filter: SearchFilter
    ) -> SearchQuery {

        var sql = filter.groupPrintings
            ? CardQueries.groupedSearchBase
            : CardQueries.searchBase

        var clauses: [String] = ["COALESCE(lang, 'en') = 'en'"]
        var parameters: [Any] = []

        // MARK: Name

        let trimmed = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if !trimmed.isEmpty {

            clauses.append("name LIKE ?")

            parameters.append("%\(trimmed)%")
        }

        // MARK: Rarity

        if !filter.selectedRarities.isEmpty {

            let placeholders = placeholders(
                filter.selectedRarities.count
            )

            clauses.append(
                "rarity IN (\(placeholders))"
            )

            parameters.append(
                contentsOf: filter.selectedRarities.sorted()
            )
        }

        // MARK: Sets

        if !filter.selectedSets.isEmpty {

            let placeholders = placeholders(
                filter.selectedSets.count
            )

            clauses.append(
                "set_code IN (\(placeholders))"
            )

            parameters.append(
                contentsOf: filter.selectedSets.sorted()
            )
        }

        // MARK: Artists

        if !filter.selectedArtists.isEmpty {

            let placeholders = placeholders(
                filter.selectedArtists.count
            )

            clauses.append(
                "artist IN (\(placeholders))"
            )

            parameters.append(
                contentsOf: filter.selectedArtists.sorted()
            )
        }

        // MARK: Mana Value

        if !filter.selectedManaCosts.isEmpty {

            let placeholders = placeholders(
                filter.selectedManaCosts.count
            )

            clauses.append(
                "CAST(cmc AS INTEGER) IN (\(placeholders))"
            )

            parameters.append(
                contentsOf: filter.selectedManaCosts.sorted()
            )
        }

        // MARK: Colours

        if !filter.selectedManaColors.isEmpty &&
            filter.colorFilterMode == .includesAnyOfThese {

            let colourClauses = filter.selectedManaColors.map {
                _ in "colors LIKE ?"
            }

            clauses.append(
                "(" +
                colourClauses.joined(separator: " OR ")
                + ")"
            )

            parameters.append(
                contentsOf: filter.selectedManaColors.map {
                    "%\($0.rawValue)%"
                }
            )
        }

        // MARK: Legality

        if filter.legalCardsOnly {

            clauses.append(
                "legalities LIKE ?"
            )

            parameters.append(
                "%\"commander\":\"legal\"%"
            )
        }

        // MARK: Final SQL

        if !clauses.isEmpty {

            sql += "\nWHERE\n"

            sql += clauses.joined(
                separator: "\nAND "
            )
        }

        if filter.groupPrintings {
            sql += "\n) AS grouped_cards\n"
            sql += "WHERE grouping_rank = 1\n"
            sql += CardQueries.searchOrder
        } else {
            sql += "\n"
            sql += CardQueries.searchOrder
        }

        return SearchQuery(
            sql: sql,
            parameters: parameters
        )
    }

    // MARK: Helpers

    private static func placeholders(
        _ count: Int
    ) -> String {

        Array(
            repeating: "?",
            count: count
        )
        .joined(separator: ",")
    }
}
