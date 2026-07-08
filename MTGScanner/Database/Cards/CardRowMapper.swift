//
//  CardRowMapper.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation
import SQLite3

enum CardRowMapper {

    // MARK: - Public

    static func map(
        _ statement: SQLiteStatement
    ) throws -> MTGCard {

        guard let id = text(statement, Column.cardID) else {
            throw CardRowMappingError.missingRequiredColumn("card_id")
        }

        guard let name = text(statement, Column.name) else {
            throw CardRowMappingError.missingRequiredColumn("name")
        }

        let imageUris = makeImageUris(statement)
        let prices = makePrices(statement)
        let legalities = makeLegalities(statement)

        return MTGCard(
            id: id,
            name: name,

            manaCost: text(statement, Column.manaCost),
            cmc: double(statement, Column.cmc),

            colors: stringArray(statement, Column.colors),
            colorIdentity: stringArray(statement, Column.colorIdentity),
            artist: text(statement, Column.artist),

            typeLine: text(statement, Column.typeLine) ?? "",
            oracleText: text(statement, Column.oracleText),

            power: text(statement, Column.power),
            toughness: text(statement, Column.toughness),

            rarity: text(statement, Column.rarity) ?? "unknown",

            set: text(statement, Column.setCode) ?? "",
            setName: text(statement, Column.setName) ?? "",
            collectorNumber: text(statement, Column.collectorNumber) ?? "",

            imageUris: imageUris,
            prices: prices,
            scryfallUri: url(statement, Column.scryfallUri),

            cardLayout: text(statement, Column.cardLayout),
            setType: text(statement, Column.setType),
            illustrationID: text(statement, Column.illustrationID),

            legalities: legalities,
            digital: bool(statement, Column.digital)
        )
    }

    static func map(
        statement: SQLiteStatement
    ) throws -> MTGCard {

        try map(statement)
    }
}

// MARK: - Columns

private extension CardRowMapper {

    enum Column {
        static let cardID = 0
        static let name = 1
        static let manaCost = 2
        static let cmc = 3
        static let colors = 4
        static let colorIdentity = 5
        static let artist = 6
        static let typeLine = 7
        static let oracleText = 8
        static let power = 9
        static let toughness = 10
        static let rarity = 11
        static let setCode = 12
        static let setName = 13
        static let collectorNumber = 14
        static let imageUriNormal = 15
        static let imageUriArtCrop = 16
        static let priceUsd = 17
        static let priceUsdFoil = 18
        static let scryfallUri = 19
        static let cardLayout = 20
        static let setType = 21
        static let illustrationID = 22
        static let legalities = 23
        static let digital = 24
    }
}

// MARK: - Mapping Helpers

private extension CardRowMapper {

    static func makeImageUris(
        _ statement: SQLiteStatement
    ) -> MTGCard.ImageUris? {

        let normal = url(
            statement,
            Column.imageUriNormal
        )

        let artCrop = url(
            statement,
            Column.imageUriArtCrop
        )

        guard normal != nil || artCrop != nil else {
            return nil
        }

        return MTGCard.ImageUris(
            small: nil,
            normal: normal,
            large: nil,
            artCrop: artCrop
        )
    }

    static func makePrices(
        _ statement: SQLiteStatement
    ) -> MTGCard.Prices? {

        let usd = text(
            statement,
            Column.priceUsd
        )

        let usdFoil = text(
            statement,
            Column.priceUsdFoil
        )

        guard usd != nil || usdFoil != nil else {
            return nil
        }

        return MTGCard.Prices(
            usd: usd,
            usdFoil: usdFoil,
            eur: nil
        )
    }

    static func makeLegalities(
        _ statement: SQLiteStatement
    ) -> Legalities? {

        guard
            let json = text(statement, Column.legalities),
            let data = json.data(using: .utf8)
        else {
            return nil
        }

        return try? JSONDecoder().decode(
            Legalities.self,
            from: data
        )
    }
}

// MARK: - Value Helpers

private extension CardRowMapper {

    static func text(
        _ statement: SQLiteStatement,
        _ index: Int
    ) -> String? {

        guard !statement.isNull(at: index) else {
            return nil
        }

        let value = statement.string(at: index)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value, !value.isEmpty else {
            return nil
        }

        return value
    }

    static func double(
        _ statement: SQLiteStatement,
        _ index: Int
    ) -> Double? {

        guard !statement.isNull(at: index) else {
            return nil
        }

        return statement.double(at: index)
    }

    static func url(
        _ statement: SQLiteStatement,
        _ index: Int
    ) -> URL? {

        guard let value = text(statement, index) else {
            return nil
        }

        return URL(string: value)
    }

    static func bool(
        _ statement: SQLiteStatement,
        _ index: Int
    ) -> Bool {

        guard !statement.isNull(at: index) else {
            return false
        }

        if let stringValue = statement.string(at: index)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {

            if stringValue == "1" ||
                stringValue == "true" ||
                stringValue == "yes" {
                return true
            }

            if stringValue == "0" ||
                stringValue == "false" ||
                stringValue == "no" {
                return false
            }
        }

        return statement.int(at: index) != 0
    }

    static func stringArray(
        _ statement: SQLiteStatement,
        _ index: Int
    ) -> [String]? {

        guard let value = text(statement, index) else {
            return nil
        }

        let values = value
            .split(separator: ",")
            .map {
                String($0)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter {
                !$0.isEmpty
            }

        return values.isEmpty ? nil : values
    }
}

// MARK: - Error

enum CardRowMappingError: LocalizedError {

    case missingRequiredColumn(String)

    var errorDescription: String? {
        switch self {
        case .missingRequiredColumn(let column):
            return "Missing required card column: \(column)"
        }
    }
}
