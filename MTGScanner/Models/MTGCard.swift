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
    let illustrationID: String?
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
        case illustrationID = "illustration_id"
        case legalities
    }
}

