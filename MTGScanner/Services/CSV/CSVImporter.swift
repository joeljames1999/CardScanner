//
//  CSVImporter.swift
//  TcgScanner
//
//  Created by Joel James on 03/07/2026.
//

import Foundation

final class CSVImporter {
    
    func importCSV(
        _ csv: String,
        progress: ((Double) -> Void)? = nil
    ) -> CSVImportResult {

        print("===== IMPORT STARTED =====")
        
        print(csv.prefix(500))
        let rows = csv
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        print("Rows:", rows.count)
        guard rows.count > 1 else {
            // Detect separator automatically
            let delimiter: Character

            if rows[0].contains("\t") {
                delimiter = "\t"
            } else {
                delimiter = ","
            }

            print("[CSV] Using delimiter:", delimiter == "\t" ? "TAB" : "COMMA")
            return CSVImportResult(
                entries: [],
                skippedRows: 0,
                errors: ["CSV file is empty."]
            )
        }

        let delimiter: Character

        if rows[0].contains("\t") {
            delimiter = "\t"
        } else {
            delimiter = ","
        }
        
        let headers = parseSeparatedLine(
            rows[0],
            delimiter: delimiter
        ).map {
            $0
                .replacingOccurrences(of: "\u{FEFF}", with: "")
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var imported: [CollectionEntry] = []
        imported.reserveCapacity(rows.count - 1)

        var skipped = 0
        var errors: [String] = []

        let totalRows = rows.count - 1

        for (index, line) in rows.dropFirst().enumerated() {
            
            if index % 100 == 0 {
                progress?(Double(index) / Double(totalRows))
            }

            let values = parseSeparatedLine(
                line,
                delimiter: delimiter
            )

            func value(_ names: [String]) -> String {
                for name in names {

                    guard let column = headers.firstIndex(of: name),
                          column < values.count else {
                        continue
                    }

                    return values[column]
                }

                return ""
            }

            let quantity = Int(
                value([
                    "count",
                    "quantity",
                    "qty"
                ])
            ) ?? 1

            let name = value([
                "name",
                "card name"
            ])

            guard !name.isEmpty else {

                skipped += 1

                errors.append(
                    "Row \(index + 2): Missing card name."
                )

                continue
            }

            let scryfallID = value([
                "scryfall id",
                "scryfall_id"
            ])

            let setCode = value([
                "edition",
                "set",
                "set code"
            ]).lowercased()

            let setName = value([
                "set name",
                "set_name"
            ])

            let rarity = value([
                "rarity"
            ])

            let imageURL = URL(string: value([
                "image",
                "image url",
                "image_uri",
                "imageuri"
            ]))

            let collectorNumber = value([
                "collector number",
                "collector_number",
                "number"
            ])

            let language = value([
                "language"
            ]).isEmpty
                ? "English"
                : value(["language"])

            let foilValue = value([
                "foil"
            ]).lowercased()

            let isFoil =
                foilValue == "foil" ||
                foilValue == "true" ||
                foilValue == "yes" ||
                foilValue == "1"

            let purchasePrice = Double(
                value([
                    "purchase price",
                    "price"
                ])
            )

            let condition = CardCondition.fromCSV(
                value([
                    "condition"
                ])
            )

            var card: MTGCard?

            // Fastest lookup (ManaBox)
            if !scryfallID.isEmpty {
                card = CardLookupCache.shared.card(
                    id: scryfallID
                )
            }

            // Fallback for Moxfield / generic CSVs
            if card == nil {
                card = CardLookupCache.shared.card(
                    name: name,
                    set: setCode,
                    collector: collectorNumber
                )
            }

            if let card {

                imported.append(
                    CollectionEntry(
                        from: card,
                        count: quantity,
                        condition: condition,
                        isFoil: isFoil,
                        isAltered: false,
                        language: language
                    )
                )

            } else {

                imported.append(
                    CollectionEntry(
                        count: quantity,
                        cardID: scryfallID.isEmpty ? UUID().uuidString : scryfallID,
                        name: name,
                        setCode: setCode,
                        setName: setName.isEmpty ? setCode.uppercased() : setName,
                        collectorNumber: collectorNumber,
                        rarity: rarity.isEmpty ? "unknown" : rarity.lowercased(),
                        condition: condition,
                        isFoil: isFoil,
                        isAltered: false,
                        language: language,
                        purchasePrice: purchasePrice,
                        usdPrice: purchasePrice.map {
                            String(format: "%.2f", $0)
                        },
                        imageURL: imageURL
                    )
                )
            }
        }

        progress?(1.0)

        return CSVImportResult(
            entries: imported,
            skippedRows: skipped,
            errors: errors
        )
    }
}

// MARK: - CSV Parsing

private extension CSVImporter {

    private func parseSeparatedLine(
        _ line: String,
        delimiter: Character
    ) -> [String] {

        var fields: [String] = []
        var current = ""
        var insideQuotes = false

        var index = line.startIndex

        while index < line.endIndex {

            let character = line[index]

            if character == "\"" {

                let next = line.index(after: index)

                if insideQuotes &&
                    next < line.endIndex &&
                    line[next] == "\"" {

                    current.append("\"")
                    index = next

                } else {

                    insideQuotes.toggle()
                }

            } else if character == delimiter && !insideQuotes {

                fields.append(current)
                current.removeAll(keepingCapacity: true)

            } else {

                current.append(character)
            }

            index = line.index(after: index)
        }

        fields.append(current)

        return fields.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

private extension CardCondition {

    static func fromCSV(_ value: String) -> CardCondition {

        switch value
            .trimmingCharacters(in: .whitespaces)
            .uppercased() {

        case "M", "MI", "MINT":
            return .mint

        case "NM",
             "NEAR MINT",
             "NEAR_MINT":
            return .nearMint

        case "LP",
             "LIGHTLY PLAYED",
             "LIGHTLY_PLAYED":
            return .lightlyPlayed

        case "MP",
             "MODERATELY PLAYED",
             "MODERATELY_PLAYED":
            return .good

        case "HP",
             "HEAVILY PLAYED",
             "HEAVILY_PLAYED":
            return .poor

        case "DMG", "DAMAGED":
            return .poor

        default:
            return .nearMint
        }
    }
}
