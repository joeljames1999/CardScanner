import Foundation

// MARK: - Scryfall Card Model

struct MTGCard: Decodable {
    let id: String
    let name: String

    let manaCost: String?
    let cmc: Double?

    let colors: [String]?
    let colorIdentity: [String]?
    let artist: String?

    let typeLine: String
    let oracleText: String?

    let power: String?
    let toughness: String?

    let rarity: String

    let set: String
    let setName: String
    let collectorNumber: String

    let imageUris: ImageUris?
    let prices: Prices?
    let scryfallUri: URL?
    let cardLayout: String?
    let setType: String?
    let legalities: Legalities?

    
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
        case id
        case name
        case rarity
        case power
        case toughness
        case set
        case prices

        case manaCost = "mana_cost"
        case cmc

        case colors
        case colorIdentity = "color_identity"
        case artist

        case typeLine = "type_line"
        case oracleText = "oracle_text"

        case setName = "set_name"
        case collectorNumber = "collector_number"

        case imageUris = "image_uris"
        case scryfallUri = "scryfall_uri"
        
        case cardLayout
        case setType = "set_type"
        case legalities
    }
}

// MARK: - Condition

enum CardCondition: String, Codable, CaseIterable {
    case mint = "Mint"
    case nearMint = "Near Mint"
    case good = "Good"
    case lightlyPlayed = "Lightly Played"
    case poor = "Poor"
    
    var moxfieldCode: String {
        switch self {
        case .mint:              return "MI"
        case .nearMint:         return "NM"
        case .lightlyPlayed:    return "LP"
        case .good:              return "GO"
        case .poor:              return "PO"
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
}

// MARK: - Session Entry (temporary, in-memory)

struct SessionEntry: Identifiable {

    let id: UUID

    let card: MTGCard

    var count: Int

    var condition: CardCondition

    var isFoil: Bool

    var isAltered: Bool

    var language: String

    init(
        card: MTGCard,
        count: Int = 1,
        condition: CardCondition = .nearMint,
        isFoil: Bool = false,
        isAltered: Bool = false,
        language: String = "English"
    ) {
        self.id = UUID()
        self.card = card
        self.count = count
        self.condition = condition
        self.isFoil = isFoil
        self.isAltered = isAltered
        self.language = language
    }
}

struct Legalities: Codable {
    
    let standard: String?
    let pioneer: String?
    let modern: String?
    let legacy: String?
    let vintage: String?
    let commander: String?
    let pauper: String?
    let brawl: String?
    let historic: String?
    let timeless: String?
    let explorer: String?
    let alchemy: String?
}

extension Legalities {

    var isLegalSomewhere: Bool {

        let formats: [String?] = [
            standard,
            pioneer,
            modern,
            legacy,
            vintage,
            commander,
            pauper,
            brawl,
            historic,
            timeless,
            explorer,
            alchemy
        ]

        for legality in formats {
            if legality == "legal" ||
                legality == "restricted" ||
                legality == "banned" {
                return true
            }
        }

        return false
    }
}
