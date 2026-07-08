//
//  CardRepository.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

final class CardRepository {

    private let database: Database

    init(database: Database) {
        self.database = database
    }
}

extension CardRepository {

    func card(id: String) throws -> MTGCard? {
        try CardLookup.card(
            id: id,
            database: database
        )
    }

    func cards(ids: [String]) throws -> [MTGCard] {
        try CardLookup.cards(
            ids: ids,
            database: database
        )
    }

    func search(
        query: String,
        filter: SearchFilter
    ) throws -> [MTGCard] {

        try CardSearch.search(
            query: query,
            filter: filter,
            database: database
        )
    }

    func allSets() throws -> [String] {

        try CardSets.all(database)
    }

    func allArtists() throws -> [String] {

        try CardArtists.all(database)
    }

    func statistics() throws -> CardStatisticsModel {

        try CardStatistics.statistics(database)
    }
}

extension CardRepository {

    func card(
        name: String,
        set: String,
        collectorNumber: String
    ) throws -> MTGCard? {

        try CardLookup.card(
            name: name,
            set: set,
            collectorNumber: collectorNumber,
            database: database
        )
    }

    func allPrintings(
        named name: String
    ) throws -> [MTGCard] {

        try CardLookup.allPrintings(
            named: name,
            database: database
        )
    }

    func cards(
        illustrationID: String
    ) throws -> [MTGCard] {

        try CardLookup.cards(
            illustrationID: illustrationID,
            database: database
        )
    }
}


extension CardRepository {

    func allCards() throws -> [MTGCard] {
        try CardLookup.allCards(
            database: database
        )
    }
}

