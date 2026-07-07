//
//  CollectionEntry.swift
//  TcgScanner
//
//  Created by Joel James on 19/06/2026.
//

import Foundation

struct CollectionCard {

    let entry: CollectionEntry
    let card: MTGCard
}

struct CollectionEntry: Codable, Identifiable {
    let id: UUID
    var count: Int
    let cardID: String          // Scryfall card ID
    let name: String
    let setCode: String         // e.g. "lea"
    let setName: String
    let collectorNumber: String
    let rarity: String
    var condition: CardCondition
    var isFoil: Bool
    var language: String        // e.g. "English"
    var purchasePrice: Double?
    let usdPrice: String?
    let imageURL: URL?
    let dateAdded: Date
    var isAltered: Bool

    init(
        from card: MTGCard,
        count: Int = 1,
        condition: CardCondition = .nearMint,
        isFoil: Bool = false,
        isAltered: Bool = false,
        language: String = "English"
    ) {
        self.id = UUID()
        self.count = count
        self.cardID = card.id
        self.name = card.name
        self.setCode = card.set
        self.setName = card.setName
        self.collectorNumber = card.collectorNumber
        self.rarity = card.rarity
        self.condition = condition
        self.isFoil = isFoil
        self.isAltered = isAltered
        self.language = language
        self.purchasePrice = card.prices?.usd.flatMap(Double.init)
        self.usdPrice = card.prices?.usd
        self.imageURL = card.imageUris?.normal
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
        self.isFoil = isFoil
        self.isAltered = isAltered
        self.language = language
        self.purchasePrice = purchasePrice
        self.usdPrice = usdPrice
        self.imageURL = imageURL
        self.dateAdded = dateAdded
    }
    
}
