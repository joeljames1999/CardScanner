//
//  CardArtists.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

enum CardArtists {

    static func all(
        _ database: Database
    ) throws -> [String] {

        let statement = try database.prepare(
            CardQueries.allArtists
        )

        defer {
            statement.finalize()
        }

        var artists: [String] = []

        while statement.step() {

            guard let artist = statement.string(at: 0) else {
                continue
            }

            artists.append(artist)
        }

        return artists
    }

    static func search(
        _ searchText: String,
        database: Database
    ) throws -> [String] {

        let trimmed = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return try all(database)
        }

        let statement = try database.prepare(
            CardQueries.searchArtists
        )

        defer {
            statement.finalize()
        }

        try statement.bind(
            "%\(trimmed)%",
            at: 1
        )

        var artists: [String] = []

        while statement.step() {

            guard let artist = statement.string(at: 0) else {
                continue
            }

            artists.append(artist)
        }

        return artists
    }

    static func cards(
        for artist: String,
        database: Database
    ) throws -> [MTGCard] {

        let statement = try database.prepare(
            CardQueries.cardsByArtist
        )

        defer {
            statement.finalize()
        }

        try statement.bind(
            artist,
            at: 1
        )

        var cards: [MTGCard] = []

        while statement.step() {

            cards.append(
                try CardRowMapper.map(statement)
            )
        }

        return cards
    }
}
