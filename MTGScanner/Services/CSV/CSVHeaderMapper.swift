//
//  CSVHeaderMapper.swift
//  TcgScanner
//
//  Created by Joel James on 03/07/2026.
//

import Foundation

struct CSVHeaderMapper {

    let headers: [String]

    let format: CSVFormat

    init(
        headers: [String],
        format: CSVFormat
    ) {
        self.headers = headers.map {
            $0
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        self.format = format
    }

    // MARK: - Common Fields

    var quantity: Int? {
        index(for: format.quantityHeaders)
    }

    var name: Int? {
        index(for: format.nameHeaders)
    }

    var setCode: Int? {
        index(for: format.setHeaders)
    }

    var collectorNumber: Int? {
        index(for: format.collectorNumberHeaders)
    }

    var language: Int? {
        index(for: format.languageHeaders)
    }

    var foil: Int? {
        index(for: format.foilHeaders)
    }

    var purchasePrice: Int? {
        index(for: format.purchasePriceHeaders)
    }

    var scryfallID: Int? {
        index(for: [
            "scryfall id",
            "scryfall_id",
            "oracle id",
            "oracle_id"
        ])
    }

    var cardID: Int? {
        index(for: [
            "card id",
            "cardid",
            "id"
        ])
    }

    var rarity: Int? {
        index(for: [
            "rarity"
        ])
    }

    var imageURL: Int? {
        index(for: [
            "image",
            "image url",
            "image_uri",
            "imageuri"
        ])
    }

    // MARK: - Helpers

    func value(
        at index: Int?,
        from row: [String]
    ) -> String {

        guard
            let index,
            row.indices.contains(index)
        else {
            return ""
        }

        return row[index]
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func index(
        for aliases: [String]
    ) -> Int? {

        for alias in aliases {

            if let index = headers.firstIndex(of: alias) {
                return index
            }
        }

        return nil
    }
}
