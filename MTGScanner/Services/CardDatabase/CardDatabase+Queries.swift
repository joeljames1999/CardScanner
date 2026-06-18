//
//  CardDatabase+Queries.swift
//  TcgScanner
//
//  Created by Joel James on 17/06/2026.
//

import Foundation
import SQLite3

extension CardDatabaseService {
    
    var isEmpty: Bool {

        print("[DB] Checking isEmpty")

        guard db != nil else {
            print("[DB] db is nil")
            return true
        }

        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(
            db,
            "SELECT COUNT(*) FROM cards;",
            -1,
            &stmt,
            nil
        ) == SQLITE_OK else {

            print(
                "[DB] COUNT query failed:",
                String(cString: sqlite3_errmsg(db))
            )

            return true
        }

        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            print("[DB] COUNT query returned no row")
            return true
        }

        let count = sqlite3_column_int(stmt, 0)

        print("[DB] Card count =", count)

        return count == 0
    }
    
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
                if let card = CardRowMapper.map(stmt) { results.append(card) }
            }
            return results
        }
    }
    
    func allCards() -> [MTGCard] {

        databaseQueue.sync {

            let sql = """
            SELECT *
            FROM cards;
            """

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

            var cards: [MTGCard] = []

            while sqlite3_step(stmt) == SQLITE_ROW {

                if let card = CardRowMapper.map(stmt) {
                    cards.append(card)
                }
            }

            return cards
        }
    }
    
    func cardCount() -> Int {

        databaseQueue.sync {

            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(
                db,
                "SELECT COUNT(*) FROM cards;",
                -1,
                &stmt,
                nil
            ) == SQLITE_OK else {
                return 0
            }

            defer {
                sqlite3_finalize(stmt)
            }

            guard sqlite3_step(stmt) == SQLITE_ROW else {
                return 0
            }

            return Int(
                sqlite3_column_int64(stmt, 0)
            )
        }
    }
}

