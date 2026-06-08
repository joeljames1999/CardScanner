import Foundation
import UIKit
import SQLite3

final class CardDatabaseService {
    
    static let shared = CardDatabaseService()
    
    private var db: OpaquePointer?
    private var insertStmt: OpaquePointer?
    
    private let databaseQueue = DispatchQueue(
        label: "com.tcgcompanion.database"
    )
    
    // Bump this when the schema changes — triggers automatic wipe + re-download
    private let schemaVersion = 4
    
    private enum CardColumn {
        static let cardID: Int32 = 0
        static let name: Int32 = 1
        static let manaCost: Int32 = 2
        static let cmc: Int32 = 3
        static let colors: Int32 = 4
        static let colorIdentity: Int32 = 5
        static let artist: Int32 = 6
        static let typeLine: Int32 = 7
        static let oracleText: Int32 = 8
        static let power: Int32 = 9
        static let toughness: Int32 = 10
        static let rarity: Int32 = 11
        static let setCode: Int32 = 12
        static let setName: Int32 = 13
        static let collectorNumber: Int32 = 14
        static let imageUri: Int32 = 15
        static let priceUsd: Int32 = 16
        static let priceUsdFoil: Int32 = 17
        static let scryfallUri: Int32 = 18
    }
    
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
        
            colors           TEXT,
            color_identity   TEXT,
            artist           TEXT,
        
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
            card_id,
            name,
            mana_cost,
            cmc,
        
            colors,
            color_identity,
            artist,
        
            type_line,
            oracle_text,
            power,
            toughness,
            rarity,
            set_code,
            set_name,
            collector_number,
            image_uri_normal,
            price_usd,
            price_usd_foil,
            scryfall_uri
        )
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);
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
        
        databaseQueue.sync {
            sqlite3_exec(
                db,
                "BEGIN IMMEDIATE TRANSACTION;",
                nil,
                nil,
                nil
            )
            
            for card in jsonArray {
                insertCard(card)
            }
            
            sqlite3_exec(
                db,
                "COMMIT;",
                nil,
                nil,
                nil
            )
        }
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
        let colors =
        (card["colors"] as? [String])?
            .sorted()
            .joined(separator: ",")
        
        let colorIdentity =
        (card["color_identity"] as? [String])?
            .sorted()
            .joined(separator: ",")
        
        let artist =
        card["artist"] as? String
        
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
        bind(stmt, 5, colors)
        bind(stmt, 6, colorIdentity)
        bind(stmt, 7, artist)
        
        bind(stmt, 8, typeLine)
        bind(stmt, 9, oracleText)
        bind(stmt, 10, power)
        bind(stmt, 11, toughness)
        bind(stmt, 12, rarity)
        bind(stmt, 13, setCode)
        bind(stmt, 14, setName)
        bind(stmt, 15, colNum)
        bind(stmt, 16, imageUri)
        bind(stmt, 17, priceUsd)
        bind(stmt, 18, priceUsdF)
        bind(stmt, 19, scryfUri)
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[CardDB] Insert error: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_reset(stmt)
        
    }
    
    // MARK: - Queries
    
    func findCard(named name: String) -> MTGCard? {
        databaseQueue.sync {

           
            
            return query("SELECT * FROM cards WHERE name = ? COLLATE NOCASE LIMIT 1;", param: name)
            ?? query("SELECT * FROM cards WHERE name LIKE ? COLLATE NOCASE LIMIT 1;", param: "%\(name)%")
        }
    }
    
    func findCards(fuzzyName search: String) -> [MTGCard] {
        databaseQueue.sync {
           
            let cleaned = search
                .replacingOccurrences(of: "0", with: "O")
                .replacingOccurrences(of: "1", with: "I")
                .replacingOccurrences(of: "|", with: "I")
                .replacingOccurrences(of: "—", with: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !cleaned.isEmpty else {
                return []
            }
            
            // Exact match
            
            let exact = queryCards(
            """
            SELECT *
            FROM cards
            WHERE name = ?
            COLLATE NOCASE
            ORDER BY rowid DESC;
            """,
            param: cleaned
            )
            
            if !exact.isEmpty {
                return exact
            }
            
            // Contains match
            
            let contains = queryCards(
            """
            SELECT *
            FROM cards
            WHERE name LIKE ?
            COLLATE NOCASE
            LIMIT 50;
            """,
            param: "%\(cleaned)%"
            )
            
            if !contains.isEmpty {
                return contains
            }
            
            // First word match
            
            let firstWord = cleaned
                .split(separator: " ")
                .first
                .map(String.init) ?? cleaned
            
            return queryCards(
            """
            SELECT *
            FROM cards
            WHERE name LIKE ?
            COLLATE NOCASE
            LIMIT 50;
            """,
            param: "\(firstWord)%"
            )
        }
    }
    
    func findCard(byCardId cardId: String) -> MTGCard? {
        databaseQueue.sync {
           
            return query("SELECT * FROM cards WHERE card_id = ? LIMIT 1;", param: cardId)
        }
    }
    
    func allPrintings(named name: String) -> [MTGCard] {
        databaseQueue.sync {
           
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
    }
    
    // MARK: - Art Hashes
    
    func storeArtHash(cardId: String, hash: UInt64) {
        databaseQueue.sync {
           
            let sql = "INSERT OR REPLACE INTO art_hashes (card_id, phash) VALUES (?, ?);"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, cardId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int64(stmt, 2, Int64(bitPattern: hash))
            sqlite3_step(stmt)
        }
    }
    
    func hasArtHash(cardId: String) -> Bool {
        databaseQueue.sync {
           
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(
                db, "SELECT 1 FROM art_hashes WHERE card_id = ?;",
                -1, &stmt, nil
            ) == SQLITE_OK else { return false }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, cardId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            return sqlite3_step(stmt) == SQLITE_ROW
        }
    }
    
    func findCardCandidatesByArtHash(
        _ hash: UInt64,
        limit: Int = 10
    ) -> [(card: MTGCard, distance: Int)] {
        databaseQueue.sync {
           
            let sql = "SELECT card_id, phash FROM art_hashes;"
            var stmt: OpaquePointer?
            
            guard sqlite3_prepare_v2(
                db,
                sql,
                -1,
                &stmt,
                nil
            ) == SQLITE_OK else {
                return []
            }
            
            defer {
                sqlite3_finalize(stmt)
            }
            
            var matches: [(String, Int)] = []
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                
                guard let ptr = sqlite3_column_text(stmt, 0) else {
                    continue
                }
                
                let cardId = String(cString: ptr)
                
                let storedHash = UInt64(
                    bitPattern: sqlite3_column_int64(stmt, 1)
                )
                
                let distance = ArtHashService.shared.hammingDistance(
                    hash,
                    storedHash
                )
                
                matches.append((cardId, distance))
            }
            
            let bestMatches = matches
                .sorted { $0.1 < $1.1 }
                .prefix(limit)
            
            return bestMatches.compactMap { cardId, distance in
                guard let card = findCard(byCardId: cardId) else {
                    return nil
                }
                
                return (card, distance)
            }
        }
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
    
    // MARK: - Search
    
    func searchCards(
        query: String,
        filter: SearchFilter
    ) -> [MTGCard] {

        databaseQueue.sync {
            print("========== SEARCH ==========")
            print("Query: \(query)")
            print("Selected colours: \(filter.selectedManaColors)")
            print("Selected rarities: \(filter.selectedRarities)")
            print("Selected sets: \(filter.selectedSets)")
            print("Selected mana costs: \(filter.selectedManaCosts)")
            print("============================")
            
            
            let trimmed = query.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !trimmed.isEmpty || filter.hasActiveFilters else {
                return []
            }

            var whereClauses: [String] = []
            var params: [String] = []

            if !trimmed.isEmpty {

                let cleaned = trimmed
                    .replacingOccurrences(of: "0", with: "O")
                    .replacingOccurrences(of: "1", with: "I")
                    .replacingOccurrences(of: "|", with: "I")

                whereClauses.append("name LIKE ? COLLATE NOCASE")
                params.append("%\(cleaned)%")

                print("ADDED TEXT CLAUSE")
                print(whereClauses)
                print(params)
            }
            
            print("1 trimmed =", trimmed)

            if !trimmed.isEmpty {

                print("2 entering text block")

                let cleaned = trimmed
                    .replacingOccurrences(of: "0", with: "O")
                    .replacingOccurrences(of: "1", with: "I")
                    .replacingOccurrences(of: "|", with: "I")

                whereClauses.append("name LIKE ? COLLATE NOCASE")
                params.append("%\(cleaned)%")

                print("3 whereClauses =", whereClauses)
                print("4 params =", params)
            }

            print("5 before sql build")
            print("whereClauses =", whereClauses)
            print("params =", params)

            var sql = """
            SELECT *
            FROM cards
            """

            if !whereClauses.isEmpty {
                sql += " WHERE " + whereClauses.joined(separator: " AND ")
            }

            sql += " ORDER BY name ASC LIMIT 500;"
            print("SQL:")
            print(sql)

            print("Params:")
            print(params)
            
            print("selectedManaColors =", filter.selectedManaColors)
            print("selectedRarities =", filter.selectedRarities)
            print("selectedSets =", filter.selectedSets)
            print("selectedManaCosts =", filter.selectedManaCosts)

            print("whereClauses BEFORE =", whereClauses)
            return executeFilteredQuery(
                sql,
                params: params
            )
        }
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
    
    private func queryCards(
        _ sql: String,
        param: String
    ) -> [MTGCard] {
        
        var stmt: OpaquePointer?
        
        guard sqlite3_prepare_v2(
            db,
            sql,
            -1,
            &stmt,
            nil
        ) == SQLITE_OK else {
            return []
        }
        
        defer {
            sqlite3_finalize(stmt)
        }
        
        sqlite3_bind_text(
            stmt,
            1,
            param,
            -1,
            unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        )
        
        var cards: [MTGCard] = []
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let card = rowToMTGCard(stmt) {
                cards.append(card)
            }
        }
        
        return cards
    }
    
    private func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if let value { sqlite3_bind_text(stmt, index, value, -1, TRANSIENT) }
        else { sqlite3_bind_null(stmt, index) }
    }
    
    private func col(
        _ stmt: OpaquePointer?,
        _ index: Int32
    ) -> String? {

        guard let stmt else {
            return nil
        }

        let count = sqlite3_column_count(stmt)

        if index < 0 || index >= count {
            print(
                "[CardDB] OUT OF RANGE index=\(index) count=\(count)"
            )
            return nil
        }

        let type = sqlite3_column_type(stmt, index)

        if type == SQLITE_NULL {
            return nil
        }

        guard let ptr = sqlite3_column_text(stmt, index) else {
            return nil
        }

        return String(cString: ptr)
    }
    
    private func rowToMTGCard(
        _ stmt: OpaquePointer?
    ) -> MTGCard? {

        dispatchPrecondition(condition: .onQueue(databaseQueue))
        
        guard let stmt else {
            print("[CardDB] stmt nil")
            return nil
        }
        
        guard
            let name = col(stmt, CardColumn.name)
        else {
            return nil
        }
        
        let imageUris: MTGCard.ImageUris? = {
            
            guard
                let imageURL = col(
                    stmt,
                    CardColumn.imageUri
                )
            else {
                return nil
            }
            
            return MTGCard.ImageUris(
                small: nil,
                normal: URL(string: imageURL),
                large: nil,
                artCrop: nil
            )
        }()
        
        let prices: MTGCard.Prices? = {
            
            let usd = col(
                stmt,
                CardColumn.priceUsd
            )
            
            let foil = col(
                stmt,
                CardColumn.priceUsdFoil
            )
            
            guard usd != nil || foil != nil else {
                return nil
            }
            
            return MTGCard.Prices(
                usd: usd,
                usdFoil: foil,
                eur: nil
            )
        }()
        
        let colors = col(
            stmt,
            CardColumn.colors
        )?
            .split(separator: ",")
            .map(String.init)
        
        let colorIdentity = col(
            stmt,
            CardColumn.colorIdentity
        )?
            .split(separator: ",")
            .map(String.init)
        
        return MTGCard(
            id: col(
                stmt,
                CardColumn.cardID
            ) ?? UUID().uuidString,
            
            name: name,
            
            manaCost: col(
                stmt,
                CardColumn.manaCost
            ),
            
            cmc: sqlite3_column_double(
                stmt,
                CardColumn.cmc
            ),
            
            colors: colors,
            
            colorIdentity: colorIdentity,
            
            artist: col(
                stmt,
                CardColumn.artist
            ),
            
            typeLine: col(
                stmt,
                CardColumn.typeLine
            ) ?? "",
            
            oracleText: col(
                stmt,
                CardColumn.oracleText
            ),
            
            power: col(
                stmt,
                CardColumn.power
            ),
            
            toughness: col(
                stmt,
                CardColumn.toughness
            ),
            
            rarity: col(
                stmt,
                CardColumn.rarity
            ) ?? "common",
            
            set: col(
                stmt,
                CardColumn.setCode
            ) ?? "",
            
            setName: col(
                stmt,
                CardColumn.setName
            ) ?? "",
            
            collectorNumber: col(
                stmt,
                CardColumn.collectorNumber
            ) ?? "",
            
            imageUris: imageUris,
            
            prices: prices,
            
            scryfallUri: col(
                stmt,
                CardColumn.scryfallUri
            ).flatMap(URL.init(string:))
        )
    }
}

// MARK: - Filtered Search (Add to CardDatabaseService)
// FIX: Use proper pointer casting and existing col() helper

extension CardDatabaseService {

    /// Internal helper to execute filtered queries
    private func executeFilteredQuery(_ sql: String, params: [String]) -> [MTGCard] {
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(
            db,
            sql,
            -1,
            &stmt,
            nil
        ) == SQLITE_OK else {
            print("[CardDB] Filter prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }

        defer { sqlite3_finalize(stmt) }

        // Bind parameters
        for (index, param) in params.enumerated() {
            sqlite3_bind_text(
                stmt,
                Int32(index + 1),
                param,
                -1,
                unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            )
        }

        var results: [MTGCard] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let card = rowToMTGCard(stmt) {
                print(
                            "RESULT:",
                            card.name,
                            "colors:",
                            card.colors ?? []
                        )

                        results.append(card)
            }
        }

        return results
    }

    /// Get all available sets
    func getAllSets() -> [String] {
        let sql = """
        SELECT DISTINCT set_name
        FROM cards
        ORDER BY set_name ASC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }

        defer { sqlite3_finalize(stmt) }

        var sets: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            // Use existing col() helper instead of direct pointer casting
            if let setName = col(stmt, 0) {
                sets.append(setName)
            }
        }

        return sets
    }

    /// Get all available rarities
    func getAllRarities() -> [String] {
        let sql = """
        SELECT DISTINCT rarity
        FROM cards
        WHERE rarity IS NOT NULL AND rarity != ''
        ORDER BY rarity ASC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }

        defer { sqlite3_finalize(stmt) }

        var rarities: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            // Use existing col() helper instead of direct pointer casting
            if let rarity = col(stmt, 0) {
                rarities.append(rarity)
            }
        }

        return rarities
    }
}
