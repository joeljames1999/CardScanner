import Foundation

struct ScryfallImportCard: Decodable {
    let id: String
    let name: String
    let manaCost: String?
    let cmc: Double?
    let typeLine: String?
    let oracleText: String?
    let power: String?
    let toughness: String?
    let rarity: String?
    let setCode: String
    let setName: String
    let collectorNumber: String
    let priceUsd: String?
    let priceUsdF: String?
    let scryfUri: String?
    let cardLayout: String?
    let setType: String?
    let illustrationId: String?
    let colors: String?
    let colorIdentity: String?
    let artist: String?
    let imageUriNormal: String?
    let imageUriArtCrop: String?
    let legalitiesJSON: String?
    let digital: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, cmc, artist, rarity, layout, power, toughness, legalities, digital
        case manaCost = "mana_cost"
        case typeLine = "type_line"
        case oracleText = "oracle_text"
        case setCode = "set"
        case setName = "set_name"
        case collectorNumber = "collector_number"
        case priceList = "prices"
        case scryfUri = "scryfall_uri"
        case setType = "set_type"
        case illustrationId = "illustration_id"
        case imageUris = "image_uris"
        case colors
        case colorIdentity = "color_identity"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.manaCost = try container.decodeIfPresent(String.self, forKey: .manaCost)
        self.cmc = try container.decodeIfPresent(Double.self, forKey: .cmc)
        self.typeLine = try container.decodeIfPresent(String.self, forKey: .typeLine)
        self.oracleText = try container.decodeIfPresent(String.self, forKey: .oracleText)
        self.power = try container.decodeIfPresent(String.self, forKey: .power)
        self.toughness = try container.decodeIfPresent(String.self, forKey: .toughness)
        self.rarity = try container.decodeIfPresent(String.self, forKey: .rarity)
        self.setCode = try container.decode(String.self, forKey: .setCode)
        self.setName = try container.decode(String.self, forKey: .setName)
        self.collectorNumber = try container.decode(String.self, forKey: .collectorNumber)
        self.scryfUri = try container.decodeIfPresent(String.self, forKey: .scryfUri)
        self.cardLayout = try container.decodeIfPresent(String.self, forKey: .layout)
        self.setType = try container.decodeIfPresent(String.self, forKey: .setType)
        self.illustrationId = try container.decodeIfPresent(String.self, forKey: .illustrationId)
        self.artist = try container.decodeIfPresent(String.self, forKey: .artist)
        self.digital = try container.decodeIfPresent(Bool.self, forKey: .digital) ?? false

        // Flatten array structures into comma-separated text variants
        self.colors = (try container.decodeIfPresent([String].self, forKey: .colors))?.sorted().joined(separator: ",")
        self.colorIdentity = (try container.decodeIfPresent([String].self, forKey: .colorIdentity))?.sorted().joined(separator: ",")

        // Parse Prices Safely
        if let prices = try container.decodeIfPresent([String: String?].self, forKey: .priceList) {
            self.priceUsd = prices["usd"] ?? nil
            self.priceUsdF = prices["usd_foil"] ?? nil
        } else {
            self.priceUsd = nil
            self.priceUsdF = nil
        }

        // Parse Legalities blocks straight into text JSON fragments
        if let legalitiesObj = try? container.decodeIfPresent(Dictionary<String, String>.self, forKey: .legalities),
           let rawData = try? JSONSerialization.data(withJSONObject: legalitiesObj) {
            self.legalitiesJSON = String(data: rawData, encoding: .utf8)
        } else {
            self.legalitiesJSON = nil
        }

        // Extract root image elements safely
        if let uris = try container.decodeIfPresent([String: String].self, forKey: .imageUris) {
            self.imageUriNormal = uris["normal"]
            self.imageUriArtCrop = uris["art_crop"]
        } else {
            self.imageUriNormal = nil
            self.imageUriArtCrop = nil
        }
    }
}
