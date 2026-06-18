//
//  CardDatabase+Schema.swift
//  TcgScanner
//
//  Created by Joel James on 17/06/2026.
//

import Foundation
import SQLite3

extension CardDatabaseService {
    
    func openDatabase() {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            print("[CardDB] Failed to open database")
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA cache_size=-8000;", nil, nil, nil)
    }
    
    func migrateIfNeeded() {
        let stored = UserDefaults.standard.integer(forKey: "CardDBSchemaVersion")
        if stored != schemaVersion {
            print("[CardDB] Schema mismatch (\(stored) → \(schemaVersion)) — rebuilding tables.")
            sqlite3_exec(db, "DROP TABLE IF EXISTS cards;", nil, nil, nil)
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
                    image_uri_art_crop TEXT,
            price_usd        TEXT,
            price_usd_foil   TEXT,
            scryfall_uri     TEXT,
            layout           TEXT,
            set_type         TEXT,
            legalities       TEXT
        
        );
        
        CREATE INDEX IF NOT EXISTS idx_cards_name
        ON cards(name COLLATE NOCASE);
        
        CREATE TABLE IF NOT EXISTS feature_prints
        (
            card_id TEXT PRIMARY KEY,
            feature_print BLOB NOT NULL
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }
    
    func prepareInsertStatement() {

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
            image_uri_art_crop,
            price_usd,
            price_usd_foil,
            scryfall_uri,
            layout,
            set_type,
            legalities
        )
        VALUES
        (
            ?,?,?,?,?,?,
            ?,?,?,?,?,?,
            ?,?,?,?,?,?,
            ?,?,?,?,?
        );
        """

        if sqlite3_prepare_v2(
            db,
            sql,
            -1,
            &insertStmt,
            nil
        ) != SQLITE_OK {

            print(
                "[CardDB] Failed to prepare insert:",
                String(cString: sqlite3_errmsg(db))
            )
        } else {
            print("[CardDB] Insert statement prepared")
        }
    }
    
}




/*
 3. CardDatabase+Schema.swift

 Everything related to:

 openDatabase()
 migrateIfNeeded()
 createTablesIfNeeded()
 prepareInsertStatement()

 moves here.
 */
