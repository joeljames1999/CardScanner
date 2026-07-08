//
//  CardSets.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

struct CardSetInfo: Hashable {

    let code: String
    let name: String
    let cardCount: Int
}

enum CardSets {

    static func all(
        _ database: Database
    ) throws -> [String] {

        let statement = try database.prepare(
            CardQueries.allSets
        )

        defer {
            statement.finalize()
        }

        var sets: [String] = []

        while statement.step() {

            guard let code = statement.string(at: 0) else {
                continue
            }

            sets.append(code)
        }

        return sets
    }

    static func allInfo(
        _ database: Database
    ) throws -> [CardSetInfo] {

        let statement = try database.prepare(
            CardQueries.allSetInfo
        )

        defer {
            statement.finalize()
        }

        var sets: [CardSetInfo] = []

        while statement.step() {

            guard let code = statement.string(at: 0) else {
                continue
            }

            let name =
                statement.string(at: 1)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let displayName =
                name?.isEmpty == false
                ? name!
                : code.uppercased()

            let count = statement.int(at: 2)

            sets.append(
                CardSetInfo(
                    code: code,
                    name: displayName,
                    cardCount: count
                )
            )
        }

        return sets
    }

    static func search(
        _ searchText: String,
        database: Database
    ) throws -> [CardSetInfo] {

        let trimmed = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return try allInfo(database)
        }

        let statement = try database.prepare(
            CardQueries.searchSetInfo
        )

        defer {
            statement.finalize()
        }

        let pattern = "%\(trimmed)%"

        try statement.bind(pattern, at: 1)
        try statement.bind(pattern, at: 2)

        var sets: [CardSetInfo] = []

        while statement.step() {

            guard let code = statement.string(at: 0) else {
                continue
            }

            let name =
                statement.string(at: 1)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let displayName =
                name?.isEmpty == false
                ? name!
                : code.uppercased()

            let count = statement.int(at: 2)

            sets.append(
                CardSetInfo(
                    code: code,
                    name: displayName,
                    cardCount: count
                )
            )
        }

        return sets
    }
}
