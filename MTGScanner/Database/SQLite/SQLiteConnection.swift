//
//  SQLiteConnection.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation
import SQLite3

final class SQLiteConnection {

    private(set) var handle: OpaquePointer?

    init(path: String) throws {

        var db: OpaquePointer?

        guard sqlite3_open_v2(
            path,
            &db,
            SQLITE_OPEN_CREATE |
            SQLITE_OPEN_READWRITE |
            SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {

            throw DatabaseError.openFailed(
                String(
                    cString: sqlite3_errmsg(db)
                )
            )
        }

        self.handle = db
    }

    deinit {
        close()
    }

    func close() {

        guard let handle else {
            return
        }

        sqlite3_close(handle)

        self.handle = nil
    }

    func execute(_ sql: String) throws {

        guard sqlite3_exec(
            handle,
            sql,
            nil,
            nil,
            nil
        ) == SQLITE_OK else {

            throw DatabaseError.sqlite(
                String(cString: sqlite3_errmsg(handle))
            )
        }
    }
}
