import Foundation
import UIKit
import SQLite3

final class CardDatabaseService {

    static let shared = CardDatabaseService()

    private var db: OpaquePointer?
    private var insertStmt: OpaquePointer?

    // Bump this when the schema changes — triggers automatic wipe + re-download
    private let schemaVersion = 3

    private let dbURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true
        )
        return appSupport.appendingPathComponent("scryfall_cards.sqlite")
    }()

    private init() {
        openDatabase()
        migrateIfNeeded()
        prepareInsertStatement()
    }

    // MARK: - Setup

    private func openDatabase() {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            print("[CardDB] Failed to open database")
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA cache_size=-8000;", nil, nil, nil)
    }

    private func migrateIfNeeded() {
        let stored = UserDefaults.standard.integer(forKey: "CardDBSchemaVersion")
        if stored != schemaVersion {
            print("[CardDB] Schema mismatch (\(stored) → \(schemaVersion)) — rebuilding tables.")
            sqlite3_exec(db, "DROP TABLE IF EXISTS cards;", nil, nil, nil)
            sqlite3_exec(db, "DROP TABLE IF EXISTS art_hashes;", nil, nil, nil)
            UserDefaults.standard.removeObject(forKey: "ScryfallBulkLastUpdated")
            UserDefaults.standard.set(schemaVersion, forKey: "CardDBSchemaVersion")
        }
        createTablesIfNeeded()
    }

    private func createTablesIfNeeded() {
        let sql = """
        CREATE TABLE IF NOT EXISTS cards (
            card_id          TEXT PRIMARY KEY,
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

        CREATE INDEX IF NOT EXISTS idx_cards_name
        ON cards(name COLLATE NOCASE);

        CREATE TABLE IF NOT EXISTS art_hashes (
            card_id TEXT PRIMARY KEY,
            phash   INTEGER NOT NULL
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func prepareInsertStatement() {
        let sql = """
        INSERT OR REPLACE INTO cards
        (
            card_id, name, mana_cost, cmc, type_line, oracle_text,
            power, toughness, rarity, set_code, set_name,
            collector_number, image_uri_normal, price_usd,
            price_usd_foil, scryfall_uri
        )
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);
        """
        if sqlite3_prepare_v2(db, sql, -1, &insertStmt, nil) != SQLITE_OK {
            print("[CardDB] Failed to prepare insert: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    // MARK: - Import

    /// Always clears — call once before streaming import begins.
    func clearCards() {
        sqlite3_exec(db, "DELETE FROM cards;", nil, nil, nil)
        sqlite3_exec(db, "DELETE FROM art_hashes;", nil, nil, nil)
        print("[CardDB] Cleared all cards and hashes.")
    }

    /// Legacy name kept for compatibility — always clears regardless of isEmpty.
    func clearCardsIfNeeded() {
        clearCards()
    }

    func checkpoint() {
        sqlite3_exec(db, "PRAGMA wal_checkpoint(FULL);", nil, nil, nil)
    }

    func importCards(_ jsonArray: [[String: Any]]) {
        sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
        for card in jsonArray { insertCard(card) }
        sqlite3_exec(db, "COMMIT;", nil, nil, nil)
    }

    private func insertCard(_ card: [String: Any]) {
        guard let stmt = insertStmt else {
            print("[CardDB] insertStmt nil — cannot insert")
            return
        }

        let TRANSIENT  = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let cardId     = card["id"] as? String ?? UUID().uuidString
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

        let imageUri: String? = {
            if let uris = card["image_uris"] as? [String: String] { return uris["normal"] }
            if let faces = card["card_faces"] as? [[String: Any]],
               let uris  = faces.first?["image_uris"] as? [String: String] { return uris["normal"] }
            return nil
        }()

        sqlite3_bind_text(stmt, 1, cardId, -1, TRANSIENT)
        sqlite3_bind_text(stmt, 2, name,   -1, TRANSIENT)
        bind(stmt, 3,  manaCost)
        sqlite3_bind_double(stmt, 4, cmc)
        bind(stmt, 5,  typeLine)
        bind(stmt, 6,  oracleText)
        bind(stmt, 7,  power)
        bind(stmt, 8,  toughness)
        bind(stmt, 9,  rarity)
        bind(stmt, 10, setCode)
        bind(stmt, 11, setName)
        bind(stmt, 12, colNum)
        bind(stmt, 13, imageUri)
        bind(stmt, 14, priceUsd)
        bind(stmt, 15, priceUsdF)
        bind(stmt, 16, scryfUri)

        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[CardDB] Insert error: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_reset(stmt)
    }

    // MARK: - Queries

    func findCard(named name: String) -> MTGCard? {
        query("SELECT * FROM cards WHERE name = ? COLLATE NOCASE LIMIT 1;", param: name)
        ?? query("SELECT * FROM cards WHERE name LIKE ? COLLATE NOCASE LIMIT 1;", param: "%\(name)%")
    }

    func findCard(byCardId cardId: String) -> MTGCard? {
        query("SELECT * FROM cards WHERE card_id = ? LIMIT 1;", param: cardId)
    }

    func allPrintings(named name: String) -> [MTGCard] {
        let sql = """
        SELECT * FROM cards
        WHERE name = ? COLLATE NOCASE
        ORDER BY rowid DESC;
        """
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

    func storeArtHash(cardId: String, hash: UInt64) {
        let sql = "INSERT OR REPLACE INTO art_hashes (card_id, phash) VALUES (?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, cardId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int64(stmt, 2, Int64(bitPattern: hash))
        sqlite3_step(stmt)
    }

    func hasArtHash(cardId: String) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db, "SELECT 1 FROM art_hashes WHERE card_id = ?;",
            -1, &stmt, nil
        ) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, cardId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
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
            let cardId   = String(cString: ptr)
            let stored   = UInt64(bitPattern: sqlite3_column_int64(stmt, 1))
            let distance = ArtHashService.shared.hammingDistance(hash, stored)
            if distance < bestDistance {
                bestDistance = distance
                bestCardId   = cardId
            }
        }

        guard let id = bestCardId, let card = findCard(byCardId: id) else { return nil }
        return (card, bestDistance)
    }

    func ensureArtHash(
        cardId: String,
        imageURL: URL
    ) async {

        if hasArtHash(cardId: cardId) {
            return
        }

        guard
            let (data, _) = try? await URLSession.shared.data(from: imageURL),
            let image = UIImage(data: data)
        else {
            return
        }

        let artService = ArtHashService.shared

        guard
            let crop = artService.cropArtRegion(from: image),
            let hash = artService.pHash(of: crop)
        else {
            return
        }

        storeArtHash(
            cardId: cardId,
            hash: hash
        )
    }
    
    // MARK: - Stats

    var isEmpty: Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db, "SELECT COUNT(*) FROM cards;", -1, &stmt, nil
        ) == SQLITE_OK else { return true }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return true }
        let count = sqlite3_column_int(stmt, 0)
        print("[CardDB] card count: \(count)")
        return count == 0
    }

    var artHashCount: Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db, "SELECT COUNT(*) FROM art_hashes;", -1, &stmt, nil
        ) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    // MARK: - Helpers

    private func query(_ sql: String, param: String) -> MTGCard? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, param, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return rowToMTGCard(stmt)
    }

    private func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if let value { sqlite3_bind_text(stmt, index, value, -1, TRANSIENT) }
        else { sqlite3_bind_null(stmt, index) }
    }

    private func col(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let ptr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: ptr)
    }

    private func rowToMTGCard(_ stmt: OpaquePointer?) -> MTGCard? {
        // card_id(0), name(1), mana_cost(2), cmc(3), type_line(4),
        // oracle_text(5), power(6), toughness(7), rarity(8),
        // set_code(9), set_name(10), collector_number(11),
        // image_uri_normal(12), price_usd(13), price_usd_foil(14), scryfall_uri(15)
        guard let name = col(stmt, 1) else { return nil }

        let imageUris: MTGCard.ImageUris? = col(stmt, 12).map {
            MTGCard.ImageUris(small: nil, normal: URL(string: $0), large: nil, artCrop: nil)
        }
        let prices: MTGCard.Prices? = {
            let usd  = col(stmt, 13)
            let foil = col(stmt, 14)
            guard usd != nil || foil != nil else { return nil }
            return MTGCard.Prices(usd: usd, usdFoil: foil, eur: nil)
        }()

        return MTGCard(
            id:              col(stmt, 0) ?? UUID().uuidString,
            name:            name,
            manaCost:        col(stmt, 2),
            cmc:             sqlite3_column_double(stmt, 3),
            typeLine:        col(stmt, 4) ?? "",
            oracleText:      col(stmt, 5),
            power:           col(stmt, 6),
            toughness:       col(stmt, 7),
            rarity:          col(stmt, 8) ?? "common",
            set:             col(stmt, 9) ?? "",
            setName:         col(stmt, 10) ?? "",
            collectorNumber: col(stmt, 11) ?? "",
            imageUris:       imageUris,
            prices:          prices,
            scryfallUri:     col(stmt, 15).flatMap(URL.init(string:))
        )
    }
}
