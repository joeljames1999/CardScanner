//
//  BulkImportRepository.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

//
//  AppDatabase.swift
//  TcgScanner
//

import Foundation

final class AppDatabase {

    static let shared = AppDatabase()

    let database: Database

    let cards: CardRepository
    let featurePrints: FeaturePrintRepository
    let bulkImport: BulkImportRepository

    private init() {

        let folder = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        try? FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )

        let url = folder.appendingPathComponent(
            "scryfall_cards.sqlite"
        )

        self.database = Database(url: url)

        do {
            try database.open()
            try? database.execute("ALTER TABLE cards ADD COLUMN card_faces_json TEXT;")
        } catch {
            print("[AppDatabase] Failed to open:", error)
        }

        self.cards = CardRepository(database: database)
        self.featurePrints = FeaturePrintRepository(database: database)
        self.bulkImport = BulkImportRepository(database: database)
    }
}

//
//  BulkImportResult.swift
//  TcgScanner
//

import Foundation

struct BulkImportResult: Equatable {

    let decodedCount: Int
    let insertedCount: Int
    let skippedCount: Int
    let databaseCount: Int

    var didImportCards: Bool {
        insertedCount > 0
    }
}

struct BulkImportProgress: Equatable {

    let total: Int
    let processed: Int
    let inserted: Int
    let skipped: Int

    var fractionCompleted: Double {
        guard total > 0 else { return 0 }
        return Double(processed) / Double(total)
    }
}

//
//  BulkImportQueries.swift
//  TcgScanner
//

import Foundation

enum BulkImportQueries {

    // MARK: - Transaction

    static let beginImmediate = """
    BEGIN IMMEDIATE TRANSACTION;
    """

    static let commit = """
    COMMIT;
    """

    static let rollback = """
    ROLLBACK;
    """

    // MARK: - Pragmas

    static let fastImportPragmas = [
        "PRAGMA foreign_keys = OFF;",
        "PRAGMA synchronous = OFF;",
        "PRAGMA cache_size = -131072;",
        "PRAGMA temp_store = MEMORY;"
    ]

    static let restorePragmas = [
        "PRAGMA foreign_keys = ON;",
        "PRAGMA journal_mode = WAL;",
        "PRAGMA synchronous = NORMAL;",
        "PRAGMA cache_size = -16000;",
        "PRAGMA temp_store = MEMORY;"
    ]

    static let checkpoint = """
    PRAGMA wal_checkpoint(FULL);
    """

    // MARK: - Clear

    static let deleteFeaturePrints = """
    DELETE FROM feature_prints;
    """

    static let deleteCards = """
    DELETE FROM cards;
    """

    // MARK: - Indexes

    static let dropImportIndexes = [
        "DROP INDEX IF EXISTS idx_cards_name;",
        "DROP INDEX IF EXISTS idx_cards_set;",
        "DROP INDEX IF EXISTS idx_cards_rarity;",
        "DROP INDEX IF EXISTS idx_cards_artist;",
        "DROP INDEX IF EXISTS idx_cards_illustration;",
        "DROP INDEX IF EXISTS idx_cards_illustration_id;",
        "DROP INDEX IF EXISTS idx_cards_fuzzy_name;"
    ]

    static let createImportIndexes = [
        """
        CREATE INDEX IF NOT EXISTS idx_cards_name
        ON cards(name COLLATE NOCASE);
        """,

        """
        CREATE INDEX IF NOT EXISTS idx_cards_set
        ON cards(set_code COLLATE NOCASE);
        """,

        """
        CREATE INDEX IF NOT EXISTS idx_cards_rarity
        ON cards(rarity COLLATE NOCASE);
        """,

        """
        CREATE INDEX IF NOT EXISTS idx_cards_artist
        ON cards(artist COLLATE NOCASE);
        """,

        """
        CREATE INDEX IF NOT EXISTS idx_cards_illustration
        ON cards(illustration_id);
        """
    ]

    // MARK: - Insert

    static let insertCard = """
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
        image_uri_art_crop,
        price_usd,
        price_usd_foil,
        scryfall_uri,
        layout,
        set_type,
        illustration_id,
        legalities,
        digital,
        card_faces_json
    )
    VALUES
    (
        ?,?,?,?,?,?,
        ?,?,?,?,?,?,
        ?,?,?,?,?,?,
        ?,?,?,?,?,?,
        ?,?
    );
    """

    // MARK: - Count

    static let countCards = """
    SELECT COUNT(*)
    FROM cards;
    """
}

//
//  BulkImportRepository.swift
//  TcgScanner
//

import Foundation

final class BulkImportRepository {

    private let database: Database

    init(database: Database) {
        self.database = database
    }
}

// MARK: - Public

extension BulkImportRepository {

    @discardableResult
    func importCards(
        fromFileAt fileURL: URL,
        progress: ((BulkImportProgress) -> Void)? = nil
    ) throws -> BulkImportResult {

        let decodedCards = try decodeCards(
            from: fileURL
        )

        try applyFastImportSettings()

        var transactionStarted = false

        do {
            try database.execute(
                BulkImportQueries.beginImmediate
            )

            transactionStarted = true

            try clearExistingData()
            try dropIndexesForImport()

            let insertStatement = try database.prepare(
                BulkImportQueries.insertCard
            )

            defer {
                insertStatement.finalize()
            }

            var inserted = 0
            var skipped = 0

            for card in decodedCards {

                if shouldSkip(card) {
                    skipped += 1
                    reportProgressIfNeeded(
                        total: decodedCards.count,
                        inserted: inserted,
                        skipped: skipped,
                        progress: progress
                    )
                    continue
                }

                try insert(
                    card,
                    using: insertStatement
                )

                inserted += 1

                reportProgressIfNeeded(
                    total: decodedCards.count,
                    inserted: inserted,
                    skipped: skipped,
                    progress: progress
                )
            }

            try rebuildIndexes()

            try database.execute(
                BulkImportQueries.commit
            )

            transactionStarted = false

            try restoreDefaultSettings()
            try checkpoint()

            let databaseCount = try countCards()

            return BulkImportResult(
                decodedCount: decodedCards.count,
                insertedCount: inserted,
                skippedCount: skipped,
                databaseCount: databaseCount
            )

        } catch {

            if transactionStarted {
                try? database.execute(
                    BulkImportQueries.rollback
                )
            }

            try? restoreDefaultSettings()

            throw error
        }
    }

    func clearCardsAndFeaturePrints() throws {
        try database.execute(BulkImportQueries.deleteFeaturePrints)
        try database.execute(BulkImportQueries.deleteCards)
    }

    func checkpoint() throws {
        try database.execute(BulkImportQueries.checkpoint)
    }

    func countCards() throws -> Int {

        let statement = try database.prepare(
            BulkImportQueries.countCards
        )

        defer {
            statement.finalize()
        }

        guard statement.step() else {
            return 0
        }

        return statement.int(at: 0)
    }
}

// MARK: - Import Steps

private extension BulkImportRepository {

    func decodeCards(
        from fileURL: URL
    ) throws -> [ScryfallImportCard] {

        let data = try Data(
            contentsOf: fileURL,
            options: .mappedIfSafe
        )

        return try JSONDecoder().decode(
            [ScryfallImportCard].self,
            from: data
        )
    }

    func applyFastImportSettings() throws {

        for sql in BulkImportQueries.fastImportPragmas {
            try database.execute(sql)
        }
    }

    func restoreDefaultSettings() throws {

        for sql in BulkImportQueries.restorePragmas {
            try database.execute(sql)
        }
    }

    func clearExistingData() throws {

        try database.execute(
            BulkImportQueries.deleteFeaturePrints
        )

        try database.execute(
            BulkImportQueries.deleteCards
        )
    }

    func dropIndexesForImport() throws {

        for sql in BulkImportQueries.dropImportIndexes {
            try database.execute(sql)
        }
    }

    func rebuildIndexes() throws {

        for sql in BulkImportQueries.createImportIndexes {
            try database.execute(sql)
        }
    }
}

// MARK: - Insert

private extension BulkImportRepository {

    func insert(
        _ card: ScryfallImportCard,
        using statement: SQLiteStatement
    ) throws {

        try statement.bind(card.id, at: 1)
        try statement.bind(card.name, at: 2)

        try statement.bind(card.manaCost, at: 3)
        try statement.bind(card.cmc, at: 4)

        try statement.bind(card.colors, at: 5)
        try statement.bind(card.colorIdentity, at: 6)
        try statement.bind(card.artist, at: 7)

        try statement.bind(card.typeLine, at: 8)
        try statement.bind(card.oracleText, at: 9)

        try statement.bind(card.power, at: 10)
        try statement.bind(card.toughness, at: 11)

        try statement.bind(card.rarity, at: 12)
        try statement.bind(card.setCode, at: 13)
        try statement.bind(card.setName, at: 14)
        try statement.bind(card.collectorNumber, at: 15)

        try statement.bind(card.imageUriNormal, at: 16)
        try statement.bind(card.imageUriArtCrop, at: 17)

        try statement.bind(card.priceUsd, at: 18)
        try statement.bind(card.priceUsdF, at: 19)

        try statement.bind(card.scryfUri, at: 20)

        try statement.bind(card.cardLayout, at: 21)
        try statement.bind(card.setType, at: 22)
        try statement.bind(card.illustrationId, at: 23)

        try statement.bind(card.legalitiesJSON, at: 24)

        let digitalValue: Int? = card.digital.map {
            $0 ? 1 : 0
        }

        try statement.bind(digitalValue, at: 25)
        try statement.bind(card.cardFacesJSON, at: 26)

        try statement.execute()

        statement.reset()
    }
}

// MARK: - Filtering

private extension BulkImportRepository {

    func shouldSkip(
        _ card: ScryfallImportCard
    ) -> Bool {

        let setType = card.setType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        let setName = card.setName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let collectorNumber = card.collectorNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if card.id.isEmpty {
            return true
        }

        if card.name.isEmpty {
            return true
        }

        if card.digital == true {
            return true
        }

        if setType == "alchemy" {
            return true
        }

        if setType == "arena" {
            return true
        }

        if setName.contains("through the omenpaths") {
            return true
        }

        if collectorNumber.hasPrefix("a-") {
            return true
        }

        return false
    }
}

// MARK: - Progress

private extension BulkImportRepository {

    func reportProgressIfNeeded(
        total: Int,
        inserted: Int,
        skipped: Int,
        progress: ((BulkImportProgress) -> Void)?
    ) {

        guard let progress else {
            return
        }

        let processed = inserted + skipped

        guard processed == total || processed.isMultiple(of: 500) else {
            return
        }

        progress(
            BulkImportProgress(
                total: total,
                processed: processed,
                inserted: inserted,
                skipped: skipped
            )
        )
    }
}
