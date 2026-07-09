//
//  CollectionEntry.swift
//  TcgScanner
//
//  Created by Joel James on 19/06/2026.
//

import Foundation

struct CollectionEntry: Codable, Identifiable {
    let id: UUID
    var count: Int
    var cardID: String          // Scryfall card ID
    let name: String
    let setCode: String         // e.g. "lea"
    var setName: String
    let collectorNumber: String
    var rarity: String
    var condition: CardCondition
    var isFoil: Bool
    var finish: CardFinish?
    var language: String        // e.g. "English"
    var purchasePrice: Double?
    var usdPrice: String?
    var imageURL: URL?
    let dateAdded: Date
    var isAltered: Bool

    init(
        from card: MTGCard,
        count: Int = 1,
        condition: CardCondition = .nearMint,
        isFoil: Bool = false,
        finish: CardFinish? = nil,
        isAltered: Bool = false,
        language: String = "English"
    ) {
        let resolvedFinish = finish ?? (isFoil ? .foil : .nonfoil)

        self.id = UUID()
        self.count = count
        self.cardID = card.id
        self.name = card.name
        self.setCode = card.set
        self.setName = card.setName
        self.collectorNumber = card.collectorNumber
        self.rarity = card.rarity
        self.condition = condition
        self.finish = resolvedFinish
        self.isFoil = resolvedFinish.isFoilLike
        self.isAltered = isAltered
        self.language = language
        self.purchasePrice = card.prices?.usd.flatMap(Double.init)
        self.usdPrice = card.prices?.usd
        self.imageURL = card.displayImage
        self.dateAdded = Date()
    }
    
    init(
        id: UUID = UUID(),
        count: Int,
        cardID: String,
        name: String,
        setCode: String,
        setName: String,
        collectorNumber: String,
        rarity: String,
        condition: CardCondition,
        isFoil: Bool,
        finish: CardFinish? = nil,
        isAltered: Bool,
        language: String,
        purchasePrice: Double?,
        usdPrice: String?,
        imageURL: URL?,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.count = count
        self.cardID = cardID
        self.name = name
        self.setCode = setCode
        self.setName = setName
        self.collectorNumber = collectorNumber
        self.rarity = rarity
        self.condition = condition
        self.finish = finish ?? (isFoil ? .foil : .nonfoil)
        self.isFoil = self.finish?.isFoilLike ?? isFoil
        self.isAltered = isAltered
        self.language = language
        self.purchasePrice = purchasePrice
        self.usdPrice = usdPrice
        self.imageURL = imageURL
        self.dateAdded = dateAdded
    }
    
}
