//
//  CollectionSummary.swift
//  TcgScanner
//
//  Created by Joel James on 06/07/2026.
//

import Foundation

struct CollectionSummary {

    let totalCards: Int
    let totalUniqueCards: Int
    let totalValue: Double

    init(entries: [CollectionEntry]) {

        self.totalCards = entries.reduce(0) { $0 + $1.count }

        self.totalUniqueCards = entries.count

        self.totalValue = entries.reduce(0) { partial, entry in

            let price = entry.usdPrice.flatMap(Double.init) ?? 0
            return partial + (price * Double(entry.count))
        }
    }

    // MARK: - Formatting helpers

    var formattedCardCount: String {
        "\(totalCards)"
    }

    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"

        return formatter.string(from: NSNumber(value: totalValue)) ?? "$0.00"
    }
}
