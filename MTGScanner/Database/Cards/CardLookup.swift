//
//  CardLookup.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

enum CardLookup {

    // MARK: - Single Card

    static func card(
        id: String,
        database: Database
    ) throws -> MTGCard? {

        let statement = try database.prepare(
            CardQueries.cardByID
        )

        defer {
            statement.finalize()
        }

        try statement.bind(
            id,
            at: 1
        )

        guard statement.step() else {
            return nil
        }

        return try CardRowMapper.map(
            statement
        )
    }

    // MARK: - Multiple Cards

    static func cards(
        ids: [String],
        database: Database
    ) throws -> [MTGCard] {

        let cleanedIDs = ids
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }

        guard !cleanedIDs.isEmpty else {
            return []
        }

        /*
         SQLite has a limit on bound variables.
         900 is a safe batch size across iOS versions.
        */
        let batches = cleanedIDs.chunked(
            into: 900
        )

        var cardsByID: [String: MTGCard] = [:]

        for batch in batches {

            let batchCards = try cardsBatch(
                ids: batch,
                database: database
            )

            for card in batchCards {
                cardsByID[card.id.lowercased()] = card
            }
        }

        /*
         Preserve the input order where possible.
         This is helpful for collection screens.
        */
        return cleanedIDs.compactMap {
            cardsByID[$0.lowercased()]
        }
    }

    static func allCards(
        database: Database
    ) throws -> [MTGCard] {

        let statement = try database.prepare(
            CardQueries.allCards
        )

        defer {
            statement.finalize()
        }

        var cards: [MTGCard] = []

        while statement.step() {
            cards.append(
                try CardRowMapper.map(statement)
            )
        }

        return cards
    }
    
    private static func cardsBatch(
        ids: [String],
        database: Database
    ) throws -> [MTGCard] {

        let statement = try database.prepare(
            CardQueries.cards(
                ids: ids.count
            )
        )

        defer {
            statement.finalize()
        }

        for (index, id) in ids.enumerated() {

            try statement.bind(
                id,
                at: index + 1
            )
        }

        var cards: [MTGCard] = []
        cards.reserveCapacity(
            ids.count
        )

        while statement.step() {

            cards.append(
                try CardRowMapper.map(
                    statement
                )
            )
        }

        return cards
    }

    // MARK: - Exact Printing

    static func card(
        name: String,
        set: String,
        collectorNumber: String,
        database: Database
    ) throws -> MTGCard? {

        let statement = try database.prepare(
            CardQueries.cardByPrinting
        )

        defer {
            statement.finalize()
        }

        try statement.bind(
            name,
            at: 1
        )

        try statement.bind(
            set,
            at: 2
        )

        try statement.bind(
            collectorNumber,
            at: 3
        )

        guard statement.step() else {
            return nil
        }

        return try CardRowMapper.map(
            statement
        )
    }

    static func card(
        set: String,
        collectorNumber: String,
        database: Database
    ) throws -> MTGCard? {

        let statement = try database.prepare(
            CardQueries.cardBySetAndCollectorNumber
        )

        defer {
            statement.finalize()
        }

        try statement.bind(set, at: 1)
        try statement.bind(collectorNumber, at: 2)
        try statement.bind(collectorNumber, at: 3)

        guard statement.step() else {
            return nil
        }

        return try CardRowMapper.map(statement)
    }

    // MARK: - Languages

    static func languages(
        name: String,
        set: String,
        collectorNumber: String,
        database: Database
    ) throws -> [String] {
        let statement = try database.prepare(
            CardQueries.languagesByPrinting
        )

        defer {
            statement.finalize()
        }

        try statement.bind(name, at: 1)
        try statement.bind(set, at: 2)
        try statement.bind(collectorNumber, at: 3)
        try statement.bind(collectorNumber, at: 4)

        var languages: [String] = []

        while statement.step() {
            if let language = statement.string(at: 0), !language.isEmpty {
                languages.append(language)
            }
        }

        return languages.isEmpty ? ["en"] : languages
    }

    // MARK: - All Printings

    static func allPrintings(
        named name: String,
        database: Database
    ) throws -> [MTGCard] {

        let statement = try database.prepare(
            CardQueries.allPrintings
        )

        defer {
            statement.finalize()
        }

        try statement.bind(
            name,
            at: 1
        )

        var cards: [MTGCard] = []

        while statement.step() {

            cards.append(
                try CardRowMapper.map(
                    statement
                )
            )
        }

        return cards
    }

    // MARK: - Illustration

    static func cards(
        illustrationID: String,
        database: Database
    ) throws -> [MTGCard] {

        let statement = try database.prepare(
            CardQueries.cardsByIllustrationID
        )

        defer {
            statement.finalize()
        }

        try statement.bind(
            illustrationID,
            at: 1
        )

        var cards: [MTGCard] = []

        while statement.step() {

            cards.append(
                try CardRowMapper.map(
                    statement
                )
            )
        }

        return cards
    }
}

// MARK: - Helpers

private extension Array {

    func chunked(
        into size: Int
    ) -> [[Element]] {

        guard size > 0 else {
            return [self]
        }

        var result: [[Element]] = []
        result.reserveCapacity(
            Int(
                ceil(
                    Double(count) / Double(size)
                )
            )
        )

        var index = 0

        while index < count {

            let end = Swift.min(
                index + size,
                count
            )

            result.append(
                Array(self[index..<end])
            )

            index += size
        }

        return result
    }
}
