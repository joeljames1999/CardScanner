//
//  CSVExporter.swift
//  TcgScanner
//
//  Created by Joel James on 03/07/2026.
//

import Foundation

final class CSVExporter {

    static let shared = CSVExporter()

    init() {}

    // MARK: - Public

    func export(
        entries: [CollectionEntry]
    ) -> String {

        var rows = [header]

        for entry in entries.sorted(by: sortEntries) {
            rows.append(row(for: entry))
        }

        return rows.joined(separator: "\n")
    }

    // MARK: - Header

    private var header: String {
        [
            "Count",
            "Tradelist Count",
            "Name",
            "Edition",
            "Condition",
            "Language",
            "Foil",
            "Tags",
            "Last Modified",
            "Collector Number",
            "Alter",
            "Proxy",
            "Purchase Price"
        ].joined(separator: ",")
    }

    // MARK: - Row

    private func row(
        for entry: CollectionEntry
    ) -> String {

        let lastModified =
            ISO8601DateFormatter().string(
                from: entry.dateAdded
            )

        let foil: String

        switch entry.resolvedFinish {
        case .nonfoil:
            foil = ""
        case .foil:
            foil = "foil"
        case .etched:
            foil = "etched"
        }

        let purchasePrice: String

        if let value = entry.purchasePrice {
            purchasePrice = String(
                format: "%.2f",
                value
            )
        } else {
            purchasePrice = ""
        }

        return [

            "\(entry.count)",

            // Tradelist Count
            "0",

            escape(entry.name),

            entry.setCode.uppercased(),

            entry.condition.moxfieldCode,

            escape(entry.language),

            foil,

            // Tags
            "",

            lastModified,

            escape(entry.collectorNumber),

            entry.isAltered
                ? "TRUE"
                : "FALSE",

            // Proxy
            "FALSE",

            purchasePrice

        ].joined(separator: ",")
    }

    // MARK: - Sorting

    private func sortEntries(
        lhs: CollectionEntry,
        rhs: CollectionEntry
    ) -> Bool {

        if lhs.name != rhs.name {
            return lhs.name < rhs.name
        }

        if lhs.setCode != rhs.setCode {
            return lhs.setCode < rhs.setCode
        }

        return lhs.collectorNumber < rhs.collectorNumber
    }

    // MARK: - CSV Escaping

    private func escape(
        _ string: String
    ) -> String {

        guard
            string.contains(",") ||
            string.contains("\"") ||
            string.contains("\n")
        else {
            return string
        }

        let escaped =
            string.replacingOccurrences(
                of: "\"",
                with: "\"\""
            )

        return "\"\(escaped)\""
    }
}
