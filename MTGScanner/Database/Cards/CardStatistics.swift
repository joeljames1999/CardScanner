//
//  CardStatistics.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

struct CardStatisticsModel: Equatable {

    let totalCards: Int
    let uniqueCardNames: Int
    let totalSets: Int
    let totalArtists: Int
    let cardsWithUSDPrice: Int
    let featurePrintCount: Int

    var hasImportedCards: Bool {
        totalCards > 0
    }

    var hasFeaturePrints: Bool {
        featurePrintCount > 0
    }
}

enum CardStatistics {

    static func statistics(
        _ database: Database
    ) throws -> CardStatisticsModel {

        let cardStats = try fetchCardStatistics(
            database
        )

        let featurePrintCount = try fetchFeaturePrintCount(
            database
        )

        return CardStatisticsModel(
            totalCards: cardStats.totalCards,
            uniqueCardNames: cardStats.uniqueCardNames,
            totalSets: cardStats.totalSets,
            totalArtists: cardStats.totalArtists,
            cardsWithUSDPrice: cardStats.cardsWithUSDPrice,
            featurePrintCount: featurePrintCount
        )
    }

    private static func fetchCardStatistics(
        _ database: Database
    ) throws -> (
        totalCards: Int,
        uniqueCardNames: Int,
        totalSets: Int,
        totalArtists: Int,
        cardsWithUSDPrice: Int
    ) {

        let statement = try database.prepare(
            CardQueries.statistics
        )

        defer {
            statement.finalize()
        }

        guard statement.step() else {
            return (
                totalCards: 0,
                uniqueCardNames: 0,
                totalSets: 0,
                totalArtists: 0,
                cardsWithUSDPrice: 0
            )
        }

        return (
            totalCards: statement.int(at: 0),
            uniqueCardNames: statement.int(at: 1),
            totalSets: statement.int(at: 2),
            totalArtists: statement.int(at: 3),
            cardsWithUSDPrice: statement.int(at: 4)
        )
    }

    private static func fetchFeaturePrintCount(
        _ database: Database
    ) throws -> Int {

        let statement = try database.prepare(
            CardQueries.featurePrintCount
        )

        defer {
            statement.finalize()
        }

        guard statement.step() else {
            return 0
        }

        return statement.int(at: 0)
    }
}
