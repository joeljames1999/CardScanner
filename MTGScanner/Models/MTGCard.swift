import Foundation

// MARK: - Scryfall Card Model

struct MTGCard: Decodable {
    let id: String
    let name: String
    let manaCost: String?
    let cmc: Double?
    let typeLine: String
    let oracleText: String?
    let power: String?
    let toughness: String?
    let rarity: String
    let set: String           // set code e.g. "lea"
    let setName: String
    let collectorNumber: String
    let imageUris: ImageUris?
    let prices: Prices?
    let scryfallUri: URL?

    struct ImageUris: Decodable {
        let small: URL?
        let normal: URL?
        let large: URL?
        let artCrop: URL?

        enum CodingKeys: String, CodingKey {
            case small, normal, large
            case artCrop = "art_crop"
        }
    }

    struct Prices: Decodable {
        let usd: String?
        let usdFoil: String?
        let eur: String?

        enum CodingKeys: String, CodingKey {
            case usd
            case usdFoil = "usd_foil"
            case eur
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, rarity, power, toughness, set, prices
        case manaCost        = "mana_cost"
        case cmc
        case typeLine        = "type_line"
        case oracleText      = "oracle_text"
        case setName         = "set_name"
        case collectorNumber = "collector_number"
        case imageUris       = "image_uris"
        case scryfallUri     = "scryfall_uri"
    }
}

// MARK: - Condition

enum CardCondition: String, Codable, CaseIterable {
    case nearMint      = "Near Mint"
    case lightlyPlayed = "Lightly Played"
    case moderatelyPlayed = "Moderately Played"
    case heavilyPlayed = "Heavily Played"
    case damaged       = "Damaged"

    var moxfieldCode: String {
        switch self {
        case .nearMint:         return "NM"
        case .lightlyPlayed:    return "LP"
        case .moderatelyPlayed: return "MP"
        case .heavilyPlayed:    return "HP"
        case .damaged:          return "D"
        }
    }
}

// MARK: - Collection Entry (persistent)

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

    init(from card: MTGCard, count: Int = 1, condition: CardCondition = .nearMint, isFoil: Bool = false) {
        self.id              = UUID()
        self.count           = count
        self.cardID          = card.id
        self.name            = card.name
        self.setCode         = card.set
        self.setName         = card.setName
        self.collectorNumber = card.collectorNumber
        self.rarity          = card.rarity
        self.condition       = condition
        self.isFoil          = isFoil
        self.language        = "English"
        self.purchasePrice   = card.prices?.usd.flatMap { Double($0) }
        self.usdPrice        = card.prices?.usd
        self.imageURL        = card.imageUris?.normal
        self.dateAdded       = Date()
    }
}

// MARK: - Session Entry (temporary, in-memory)

struct SessionEntry: Identifiable {
    let id: UUID
    var count: Int
    let card: MTGCard

    init(card: MTGCard, count: Int = 1) {
        self.id    = UUID()
        self.count = count
        self.card  = card
    }
}
