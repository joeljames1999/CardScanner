//
//  DatabaseHelpers.swift
//  TcgScanner
//
//  Created by Joel James on 17/06/2026.
//

import Foundation
import SQLite3

extension CardDatabaseService {
    
    func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if let value { sqlite3_bind_text(stmt, index, value, -1, TRANSIENT) }
        else { sqlite3_bind_null(stmt, index) }
    }
    
    func col(
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
    
    func query(_ sql: String, param: String) -> MTGCard? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, param, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return CardRowMapper.map(stmt)
    }
    
    func queryCards(
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
            if let card = CardRowMapper.map(stmt) {
                cards.append(card)
            }
        }
        
        return cards
    }
}
