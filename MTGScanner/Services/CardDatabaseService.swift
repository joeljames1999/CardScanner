import Foundation
import SQLite3

final class CardDatabaseService {

    static let shared = CardDatabaseService()

    private var db: OpaquePointer?
    private var insertStmt: OpaquePointer?  // prepared once, reused for streaming

    private let dbURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("scryfall_cards.sqlite")
    }()

    private init() {
        openDatabase()
        createTablesIfNeeded()
        prepareInsertStatement()
    }

    // MARK: - Setup

    private func openDatabase() {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            print("[CardDB] Failed to open: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA cache_size=-8000;", nil, nil, nil) // 8MB page cache
    }

    private func createTablesIfNeeded() {
        let sql = """
        CREATE TABLE IF NOT EXISTS cards (
            card_id          TEXT PRIMARY KEY,
            oracle_id        TEXT,
            name             TEXT NOT NULL,
            mana_cost        TEXT,
            cmc              REAL,
            type_line        TEXT,
            oracle_text      TEXT,
            power            TEXT,
            toughness        TEXT,
            rarity           TEXT,
            set_code         TEXT,
            set_name         TEXT,
            collector_number TEXT,
            image_uri_normal TEXT,
            price_usd        TEXT,
            price_usd_foil   TEXT,
            scryfall_uri     TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_cards_name ON cards(name COLLATE NOCASE);
        CREATE INDEX IF NOT EXISTS idx_cards_oracle ON cards(oracle_id);

        CREATE TABLE IF NOT EXISTS art_hashes (
            card_id  TEXT PRIMARY KEY,
            phash    INTEGER NOT NULL
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func prepareInsertStatement() {
        let sql = """
        INSERT OR REPLACE INTO cards
        (card_id, oracle_id, name, mana_cost, cmc, type_line, oracle_text, power, toughness,
         rarity, set_code, set_name, collector_number, image_uri_normal,
         price_usd, price_usd_foil, scryfall_uri)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);
        """
        sqlite3_prepare_v2(db, sql, -1, &insertStmt, nil)
    }

    // MARK: - Import (streaming-friendly)
    // Call clearCards() once before starting, then call importCards() with small batches.
    // Each batch runs in its own transaction — keeps memory flat.

    func clearCards() {
        sqlite3_exec(db, "DELETE FROM cards;", nil, nil, nil)
        sqlite3_exec(db, "DELETE FROM art_hashes;", nil, nil, nil)
    }

    func importCards(_ jsonArray: [[String: Any]]) {
        sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)

        for card in jsonArray {
            insertCard(card)
        }

        sqlite3_exec(db, "COMMIT;", nil, nil, nil)
    }

    private func insertCard(_ card: [String: Any]) {
        guard let stmt = insertStmt else { return }

        let cardId     = card["id"] as? String ?? UUID().uuidString
        let oracleId   = card["oracle_id"] as? String ?? ""
        let name       = card["name"] as? String ?? ""
        let manaCost   = card["mana_cost"] as? String
        let cmc        = card["cmc"] as? Double ?? 0
        let typeLine   = card["type_line"] as? String
        let oracleText = card["oracle_text"] as? String
        let power      = card["power"] as? String
        let toughness  = card["toughness"] as? String
        let rarity     = card["rarity"] as? String
        let setCode    = card["set"] as? String
        let setName    = card["set_name"] as? String
        let colNum     = card["collector_number"] as? String
        let prices     = card["prices"] as? [String: Any]
        let priceUsd   = prices?["usd"] as? String
        let priceUsdF  = prices?["usd_foil"] as? String
        let scryfUri   = card["scryfall_uri"] as? String

        // Handle both standard and double-faced cards
        let imageUri: String? = {
            if let uris = card["image_uris"] as? [String: String] {
                return uris["normal"]
            }
            if let faces = card["card_faces"] as? [[String: Any]],
               let uris  = faces.first?["image_uris"] as? [String: String] {
                return uris["normal"]
            }
            return nil
        }()

        let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        sqlite3_bind_text(stmt, 1,  cardId,  -1, TRANSIENT)
        sqlite3_bind_text(stmt, 2,  oracleId, -1, TRANSIENT)
        sqlite3_bind_text(stmt, 3,  name,    -1, TRANSIENT)
        bind(stmt, 4,  manaCost)
        sqlite3_bind_double(stmt, 5, cmc)
        bind(stmt, 6,  typeLine)
        bind(stmt, 7,  oracleText)
        bind(stmt, 8,  power)
        bind(stmt, 9,  toughness)
        bind(stmt, 10, rarity)
        bind(stmt, 11, setCode)
        bind(stmt, 12, setName)
        bind(stmt, 13, colNum)
        bind(stmt, 14, imageUri)
        bind(stmt, 15, priceUsd)
        bind(stmt, 16, priceUsdF)
        bind(stmt, 17, scryfUri)

        sqlite3_step(stmt)
        sqlite3_reset(stmt)
    }

    // MARK: - Queries

    func findCard(named name: String) -> MTGCard? {
        query("SELECT * FROM cards WHERE name = ? COLLATE NOCASE LIMIT 1;", param: name)
        ?? query("SELECT * FROM cards WHERE name LIKE ? COLLATE NOCASE LIMIT 1;", param: "%\(name)%")
    }

    func findCard(byOracleId oracleId: String) -> MTGCard? {
        query("SELECT * FROM cards WHERE oracle_id = ? LIMIT 1;", param: oracleId)
    }

    func findCard(byCardId cardId: String) -> MTGCard? {
        query("SELECT * FROM cards WHERE card_id = ? LIMIT 1;", param: cardId)
    }

    /// All printings of a card name, ordered newest to oldest.
    func allPrintings(named name: String) -> [MTGCard] {
        let sql = "SELECT * FROM cards WHERE name = ? COLLATE NOCASE ORDER BY rowid DESC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, name, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        var results: [MTGCard] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let card = rowToMTGCard(stmt) { results.append(card) }
        }
        return results
    }

    // MARK: - Art Hashes

    func storeArtHash(oracleId: String, hash: UInt64) {
        let sql = "INSERT OR REPLACE INTO art_hashes (card_id, phash) VALUES (?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, oracleId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int64(stmt, 2, Int64(bitPattern: hash))
        sqlite3_step(stmt)
    }

    func hasArtHash(oracleId: String) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM art_hashes WHERE card_id = ?;", -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, oracleId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    func findCardByArtHash(_ hash: UInt64) -> (card: MTGCard, distance: Int)? {
        let sql = "SELECT card_id, phash FROM art_hashes;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        var bestCardId: String?
        var bestDistance = Int.max

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let ptr = sqlite3_column_text(stmt, 0) else { continue }
            let cardId     = String(cString: ptr)
            let stored     = UInt64(bitPattern: sqlite3_column_int64(stmt, 1))
            let distance   = ArtHashService.shared.hammingDistance(hash, stored)
            if distance < bestDistance {
                bestDistance = distance
                bestCardId   = cardId
            }
        }

        guard let id = bestCardId, let card = findCard(byCardId: id) else { return nil }
        return (card, bestDistance)
    }

    // MARK: - Stats

    var isEmpty: Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM cards;", -1, &stmt, nil) == SQLITE_OK else { return true }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) != SQLITE_ROW || sqlite3_column_int(stmt, 0) == 0
    }

    var artHashCount: Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM art_hashes;", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    // MARK: - Private Helpers

    private func query(_ sql: String, param: String) -> MTGCard? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, param, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return rowToMTGCard(stmt)
    }

    private func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let v = value {
            sqlite3_bind_text(stmt, index, v, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func col(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let ptr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: ptr)
    }

    private func rowToMTGCard(_ stmt: OpaquePointer?) -> MTGCard? {
        // Columns: card_id(0), oracle_id(1), name(2), mana_cost(3), cmc(4),
        //          type_line(5), oracle_text(6), power(7), toughness(8),
        //          rarity(9), set_code(10), set_name(11), collector_number(12),
        //          image_uri_normal(13), price_usd(14), price_usd_foil(15), scryfall_uri(16)
        guard let name = col(stmt, 2) else { return nil }

        let imageUris: MTGCard.ImageUris? = col(stmt, 13).map {
            MTGCard.ImageUris(small: nil, normal: URL(string: $0), large: nil, artCrop: nil)
        }
        let prices: MTGCard.Prices? = {
            let usd  = col(stmt, 14)
            let foil = col(stmt, 15)
            guard usd != nil || foil != nil else { return nil }
            return MTGCard.Prices(usd: usd, usdFoil: foil, eur: nil)
        }()

        return MTGCard(
            id:              col(stmt, 0) ?? UUID().uuidString,
            name:            name,
            manaCost:        col(stmt, 3),
            cmc:             sqlite3_column_double(stmt, 4),
            typeLine:        col(stmt, 5) ?? "",
            oracleText:      col(stmt, 6),
            power:           col(stmt, 7),
            toughness:       col(stmt, 8),
            rarity:          col(stmt, 9) ?? "common",
            set:             col(stmt, 10) ?? "",
            setName:         col(stmt, 11) ?? "",
            collectorNumber: col(stmt, 12) ?? "",
            imageUris:       imageUris,
            prices:          prices,
            scryfallUri:     col(stmt, 16).flatMap { URL(string: $0) }
        )
    }
}
