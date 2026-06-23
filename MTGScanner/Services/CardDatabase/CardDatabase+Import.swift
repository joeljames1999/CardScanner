//
//  CardDatabase+Import.swift
//  TcgScanner
//
//  Created by Joel James on 17/06/2026.
//

import Foundation
import SQLite3

extension CardDatabaseService {
    
    func clearCards() {
        sqlite3_exec(db, "DROP INDEX IF EXISTS idx_cards_illustration_id;", nil, nil, nil)
        sqlite3_exec(db, "DROP INDEX IF EXISTS idx_cards_fuzzy_name;", nil, nil, nil)
        
        sqlite3_exec(db, "DELETE FROM cards;", nil, nil, nil)
        sqlite3_exec(db, "DELETE FROM feature_prints;", nil, nil, nil)
        
        print("[CardDB] Cleared database and temporary indexes")
    }
    
    func clearCardsIfNeeded() {
        clearCards()
    }
    
    func checkpoint() {
        sqlite3_exec(db, "PRAGMA wal_checkpoint(FULL);", nil, nil, nil)
    }
    
    /// Stream cards directly from local disk path straight into SQLite memory tables
    func importCards(fromFileAt fileURL: URL) {
        databaseQueue.sync {
            sqlite3_exec(db, "PRAGMA journal_mode=MEMORY;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA synchronous=OFF;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA cache_size=-131072;", nil, nil, nil)
            
            sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil)
            
            do {
                let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
                let decodedCards = try JSONDecoder().decode([ScryfallImportCard].self, from: data)
                
                for card in decodedCards {
                    // --- SAFE FILTERING INSTEAD OF THROWING ---
                    let sType = card.setType?.lowercased() ?? ""
                    let sName = card.setName.lowercased()
                    let cNum = card.collectorNumber.lowercased()
                    
                    if sType == "alchemy" ||
                        sType == "arena" ||
                        sName.contains("through the omenpaths") ||
                        cNum.hasPrefix("a-") {
                        if cNum == "UNF#237" {
                            print(card)
                        }
                        continue // Safely skip this entry and move onto the next card!
                    }
                    
                    insertFastCard(card)
                }
            } catch {
                print("[CardDB] Parsing stream failed: \(error)")
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                return
            }
            
            sqlite3_exec(db, "COMMIT;", nil, nil, nil)
            
            print("[CardDB] Building performance indexes on 114k+ records...")
            sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS idx_cards_illustration_id ON cards (illustration_id);", nil, nil, nil)
            sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS idx_cards_fuzzy_name ON cards (name);", nil, nil, nil)
            
            sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
            print("[CardDB] Fast streaming bulk import completed successfully")
        }
    }

    
    private func insertFastCard(_ card: ScryfallImportCard) {
        guard let stmt = insertStmt else { return }
        
        let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
        
        // Match statement bindings directly to your local columns layout
        sqlite3_bind_text(stmt, 1, card.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, card.name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, card.manaCost, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 4, card.cmc ?? 0.0)
        sqlite3_bind_text(stmt, 5, card.colors, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, card.colorIdentity, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 7, card.artist, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 8, card.typeLine, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 9, card.oracleText, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 10, card.power, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 11, card.toughness, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 12, card.rarity, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 13, card.setCode, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 14, card.setName, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 15, card.collectorNumber, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 16, card.imageUriNormal, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 17, card.imageUriArtCrop, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 18, card.priceUsd, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 19, card.priceUsdF, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 20, card.scryfUri, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 21, card.cardLayout, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 22, card.setType, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 23, card.illustrationId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 24, card.legalitiesJSON, -1, SQLITE_TRANSIENT)
        
        let result = sqlite3_step(stmt)
        if result != SQLITE_DONE {
            print("[CardDB] Insert processing error code: \(result)")
        }
        sqlite3_reset(stmt)
    }
}
