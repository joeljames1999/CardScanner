//
//  SQLiteStatement.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation
import SQLite3

final class SQLiteStatement {

    private let database: OpaquePointer?
    private var statement: OpaquePointer?
    var statementPointer: OpaquePointer? {
        statement
    }

    init(
        database: OpaquePointer?,
        sql: String
    ) throws {

        self.database = database

        var stmt: OpaquePointer?

        let result = sqlite3_prepare_v2(
            database,
            sql,
            -1,
            &stmt,
            nil
        )

        guard result == SQLITE_OK else {

            let message = database.map {
                String(cString: sqlite3_errmsg($0))
            } ?? "Database not open"

            throw DatabaseError.prepareFailed(message)
        }

        self.statement = stmt
    }

    deinit {
        finalize()
    }

    // MARK: - Lifecycle

    func finalize() {

        if let statement {
            sqlite3_finalize(statement)
            self.statement = nil
        }
    }

    func reset() {

        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
    }

    // MARK: - Step

    func step() -> Bool {

        let result = sqlite3_step(statement)

        return result == SQLITE_ROW
    }

    func execute() throws {

        let result = sqlite3_step(statement)

        guard result == SQLITE_DONE else {

            let message = database.map {
                String(cString: sqlite3_errmsg($0))
            } ?? "SQLite step failed."

            throw DatabaseError.stepFailed(message)
        }
    }
}

extension SQLiteStatement {

    func bind(
        _ value: Any,
        at index: Int
    ) throws {

        switch value {

        case let string as String:
            bindText(string, at: index)

        case let int as Int:
            sqlite3_bind_int64(
                statementPointer,
                Int32(index),
                sqlite3_int64(int)
            )

        case let double as Double:
            sqlite3_bind_double(
                statementPointer,
                Int32(index),
                double
            )

        case let bool as Bool:
            sqlite3_bind_int(
                statementPointer,
                Int32(index),
                bool ? 1 : 0
            )

        case let data as Data:
            bindBlob(data, at: index)

        case Optional<Any>.none:
            sqlite3_bind_null(
                statementPointer,
                Int32(index)
            )

        default:
            throw DatabaseError.bindFailed
        }
    }

    func bind(
        _ value: String?,
        at index: Int
    ) throws {

        guard let value else {
            sqlite3_bind_null(statementPointer, Int32(index))
            return
        }

        bindText(value, at: index)
    }

    func bind(
        _ value: Double?,
        at index: Int
    ) throws {

        guard let value else {
            sqlite3_bind_null(statementPointer, Int32(index))
            return
        }

        sqlite3_bind_double(
            statementPointer,
            Int32(index),
            value
        )
    }

    func bind(
        _ value: Int?,
        at index: Int
    ) throws {

        guard let value else {
            sqlite3_bind_null(statementPointer, Int32(index))
            return
        }

        sqlite3_bind_int64(
            statementPointer,
            Int32(index),
            sqlite3_int64(value)
        )
    }
}

private extension SQLiteStatement {

    var transient: sqlite3_destructor_type {
        unsafeBitCast(
            -1,
            to: sqlite3_destructor_type.self
        )
    }

    func bindText(
        _ value: String,
        at index: Int
    ) {

        sqlite3_bind_text(
            statementPointer,
            Int32(index),
            value,
            -1,
            transient
        )
    }

    func bindBlob(
        _ data: Data,
        at index: Int
    ) {

        data.withUnsafeBytes { buffer in

            sqlite3_bind_blob(
                statementPointer,
                Int32(index),
                buffer.baseAddress,
                Int32(data.count),
                transient
            )
        }
    }
}

extension SQLiteStatement {

    func string(
        at index: Int
    ) -> String? {

        guard let text = sqlite3_column_text(
            statementPointer,
            Int32(index)
        ) else {
            return nil
        }

        return String(
            cString: text
        )
    }

    func int(
        at index: Int
    ) -> Int {

        Int(
            sqlite3_column_int64(
                statementPointer,
                Int32(index)
            )
        )
    }

    func double(
        at index: Int
    ) -> Double {

        sqlite3_column_double(
            statementPointer,
            Int32(index)
        )
    }

    func data(
        at index: Int
    ) -> Data? {

        guard let bytes = sqlite3_column_blob(
            statementPointer,
            Int32(index)
        ) else {
            return nil
        }

        let count = sqlite3_column_bytes(
            statementPointer,
            Int32(index)
        )

        return Data(
            bytes: bytes,
            count: Int(count)
        )
    }
}

extension SQLiteStatement {

    func isNull(
        at index: Int
    ) -> Bool {

        sqlite3_column_type(
            statementPointer,
            Int32(index)
        ) == SQLITE_NULL
    }
}
