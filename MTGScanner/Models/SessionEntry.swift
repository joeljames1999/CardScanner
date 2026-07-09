//
//  SessionEntry.swift
//  TcgScanner
//
//  Created by Joel James on 19/06/2026.
//

import Foundation

struct SessionEntry: Identifiable {

    let id: UUID

    let card: MTGCard

    var count: Int

    var condition: CardCondition

    var isFoil: Bool

    var finish: CardFinish

    var isAltered: Bool

    var language: String

    init(
        card: MTGCard,
        count: Int = 1,
        condition: CardCondition = .nearMint,
        isFoil: Bool = false,
        finish: CardFinish? = nil,
        isAltered: Bool = false,
        language: String = "English"
    ) {
        let resolvedFinish = finish ?? (isFoil ? .foil : .nonfoil)

        self.id = UUID()
        self.card = card
        self.count = count
        self.condition = condition
        self.finish = resolvedFinish
        self.isFoil = resolvedFinish.isFoilLike
        self.isAltered = isAltered
        self.language = language
    }
}
