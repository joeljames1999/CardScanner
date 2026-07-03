//
//  CSVFormat.swift
//  TcgScanner
//
//  Created by Joel James on 03/07/2026.
//

import Foundation

enum CSVFormat: String {

    case moxfield
    case manabox
    case archidekt
    case deckbox
    case dragonShield
    case generic

    // MARK: - Detection

    static func detect(
        headers: [String]
    ) -> CSVFormat {

        let normalized = headers.map {
            $0
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        // Moxfield
        if normalized.contains("tradelist count"),
           normalized.contains("last modified") {
            return .moxfield
        }

        // ManaBox
        if normalized.contains("manabox id") ||
            normalized.contains("binder") {
            return .manabox
        }

        // Archidekt
        if normalized.contains("categories") ||
            normalized.contains("multiple") {
            return .archidekt
        }

        // Deckbox
        if normalized.contains("inventory id") ||
            normalized.contains("trade list count") {
            return .deckbox
        }

        // Dragon Shield
        if normalized.contains("folder") ||
            normalized.contains("purchase date") {
            return .dragonShield
        }

        return .generic
    }

    // MARK: - Display Name

    var displayName: String {

        switch self {

        case .moxfield:
            return "Moxfield"

        case .manabox:
            return "ManaBox"

        case .archidekt:
            return "Archidekt"

        case .deckbox:
            return "Deckbox"

        case .dragonShield:
            return "Dragon Shield"

        case .generic:
            return "Generic CSV"
        }
    }

    // MARK: - Preferred Header Names

    var quantityHeaders: [String] {

        switch self {

        case .generic:
            return [
                "count",
                "quantity",
                "qty"
            ]

        default:
            return [
                "count"
            ]
        }
    }

    var nameHeaders: [String] {

        switch self {

        case .generic:
            return [
                "name",
                "card",
                "card name"
            ]

        default:
            return [
                "name"
            ]
        }
    }

    var setHeaders: [String] {

        switch self {

        case .generic:
            return [
                "edition",
                "set",
                "set code"
            ]

        default:
            return [
                "edition"
            ]
        }
    }

    var collectorNumberHeaders: [String] {

        switch self {

        case .generic:
            return [
                "collector number",
                "number",
                "collector_number"
            ]

        default:
            return [
                "collector number"
            ]
        }
    }

    var languageHeaders: [String] {

        [
            "language"
        ]
    }

    var conditionHeaders: [String] {

        [
            "condition"
        ]
    }

    var foilHeaders: [String] {

        [
            "foil",
            "finish"
        ]
    }

    var purchasePriceHeaders: [String] {

        [
            "purchase price",
            "price"
        ]
    }
}
