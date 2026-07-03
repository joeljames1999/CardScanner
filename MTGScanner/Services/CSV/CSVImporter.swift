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

        CardLookupCache.shared.build()

        let rows = csv
            .split(whereSeparator: \.isNewline)
            .map(String.init)

        guard rows.count > 1 else {
            return CSVImportResult(
                entries: [],
                skippedRows: 0,
                errors: ["CSV file is empty."]
            )
        }

        let headers = parseCSVLine(rows[0])
            .map {
                $0
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

            let values = parseCSVLine(line)

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
                value(["count", "quantity", "qty"])
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

            let setCode = value([
                "edition",
                "set",
                "set code"
            ]).lowercased()

            let collectorNumber = value([
                "collector number",
                "collector_number",
                "number"
            ])

            let language = value(["language"]).isEmpty
                ? "English"
                : value(["language"])

            let foilValue = value(["foil"]).lowercased()

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
                value(["condition"])
            )

            if let card = CardLookupCache.shared.card(
                name: name,
                set: setCode,
                collector: collectorNumber
            ) {

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
                        cardID: UUID().uuidString,
                        name: name,
                        setCode: setCode,
                        setName: setCode.uppercased(),
                        collectorNumber: collectorNumber,
                        rarity: "unknown",
                        condition: condition,
                        isFoil: isFoil,
                        isAltered: false,
                        language: language,
                        purchasePrice: purchasePrice,
                        usdPrice: purchasePrice.map {
                            String(format: "%.2f", $0)
                        },
                        imageURL: nil
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

    private func parseCSVLine(_ line: String) -> [String] {

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

                    // Escaped quote ("")
                    current.append("\"")
                    index = next

                } else {

                    insideQuotes.toggle()
                }

            } else if character == "," && !insideQuotes {

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

        case "NM", "NEAR MINT":
            return .nearMint

        case "LP", "LIGHTLY PLAYED":
            return .lightlyPlayed

        case "MP", "MODERATELY PLAYED":
            return .good

        case "HP", "HEAVILY PLAYED":
            return .poor

        case "DMG", "DAMAGED":
            return .poor

        default:
            return .nearMint
        }
    }
}
