//
//  CardDatabase+Import.swift
//  TcgScanner
//
//  Created by Joel James on 17/06/2026.
//

import Foundation
import SQLite3

extension CardDatabaseService {
    
    // MARK: - Import
    
    func clearCards() {
        
        sqlite3_exec(
            db,
            "DELETE FROM cards;",
            nil,
            nil,
            nil
        )
        
        sqlite3_exec(
            db,
            "DELETE FROM feature_prints;",
            nil,
            nil,
            nil
        )
        
        print("[CardDB] Cleared database")
    }
    
    func clearCardsIfNeeded() {
        clearCards()
    }
    
    func checkpoint() {
        
        sqlite3_exec(
            db,
            "PRAGMA wal_checkpoint(FULL);",
            nil,
            nil,
            nil
        )
    }
    
    func importCards(
        _ jsonArray: [[String: Any]]
    ) {
        
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
    
    func insertCard(
        _ card: [String: Any]
    ) {
        
        let setType = card["set_type"] as? String
        let setTypeLowercased = setType?.lowercased()
        let setname  = card["set_name"] as? String
        let collectorNumber = card["collector_number"] as? String
        
        if setTypeLowercased == "alchemy" ||
            setTypeLowercased == "arena" ||
            setname?.lowercased().contains("through the omenpaths") == true || //Hide Arena spiderman set
            collectorNumber?.lowercased().hasPrefix("a-") == true { //hide all alchemy only cards
            return
        }
        
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
        let cardLayout = card["layout"] as? String
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
        
        let imageUriNormal: String? = {
            
            if let uris = card["image_uris"] as? [String: String] {
                return uris["normal"]
            }
            
            if let faces = card["card_faces"] as? [[String: Any]],
               let uris = faces.first?["image_uris"] as? [String: String] {
                return uris["normal"]
            }
            
            return nil
        }()
        
        let imageUriArtCrop: String? = {
            
            if let uris = card["image_uris"] as? [String: String] {
                return uris["art_crop"]
            }
            
            if let faces = card["card_faces"] as? [[String: Any]],
               let uris = faces.first?["image_uris"] as? [String: String] {
                return uris["art_crop"]
            }
            
            return nil
        }()
        
        let legalitiesJSON: String? = {
            guard let legalities = card["legalities"] else {
                return nil
            }
            
            guard let data = try? JSONSerialization.data(
                withJSONObject: legalities
            ) else {
                return nil
            }
            
            return String(
                data: data,
                encoding: .utf8
            )
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
        bind(stmt, 16, imageUriNormal)
        bind(stmt, 17, imageUriArtCrop)
        bind(stmt, 18, priceUsd)
        bind(stmt, 19, priceUsdF)
        bind(stmt, 20, scryfUri)
        bind(stmt, 21, cardLayout)
        bind(stmt, 22, setType)
        bind(stmt, 23, legalitiesJSON)
        
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            let result = sqlite3_step(stmt)
            
            if result != SQLITE_DONE {
                
                print(
                    "[CardDB] Insert error:",
                    result,
                    String(cString: sqlite3_errmsg(db))
                )
            }
        }
        sqlite3_reset(stmt)
    }
}
