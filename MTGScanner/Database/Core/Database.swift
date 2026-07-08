//
//  Database.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation
import SQLite3

final class Database {

    let url: URL

    private(set) var handle: OpaquePointer?

    init(url: URL) {
        self.url = url
    }

    deinit {
        close()
    }

    // MARK: - Lifecycle

    func open() throws {

        if handle != nil {
            return
        }

        let result = sqlite3_open_v2(
            url.path,
            &handle,
            SQLITE_OPEN_READWRITE |
            SQLITE_OPEN_CREATE |
            SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard result == SQLITE_OK else {

            let errorMessage = message()

            sqlite3_close(handle)
            handle = nil

            throw DatabaseError.openFailed(errorMessage)
        }

        try configure()
    }

    func close() {

        guard let handle else {
            return
        }

        sqlite3_close(handle)

        self.handle = nil
    }

    // MARK: - Configuration

    private func configure() throws {

        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA synchronous = NORMAL;")
        try execute("PRAGMA cache_size = -16000;")
        try execute("PRAGMA temp_store = MEMORY;")
    }

    // MARK: - Execute

    func execute(_ sql: String) throws {

        guard let handle else {
            throw DatabaseError.notOpen
        }

        let result = sqlite3_exec(
            handle,
            sql,
            nil,
            nil,
            nil
        )

        guard result == SQLITE_OK else {
            throw DatabaseError.sqlite(
                message()
            )
        }
    }

    // MARK: - Prepare

    func prepare(_ sql: String) throws -> SQLiteStatement {

        guard let handle else {
            throw DatabaseError.notOpen
        }

        return try SQLiteStatement(
            database: handle,
            sql: sql
        )
    }

    // MARK: - Error Message

    func message() -> String {

        guard let handle else {
            return "Database not open"
        }

        return String(
            cString: sqlite3_errmsg(handle)
        )
    }
}
