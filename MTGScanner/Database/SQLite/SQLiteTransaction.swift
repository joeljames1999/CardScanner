//
//  SQLiteTransaction.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

struct SQLiteTransaction {

    let database: Database

    func write(
        _ block: () throws -> Void
    ) throws {

        try database.execute("BEGIN IMMEDIATE")

        do {

            try block()

            try database.execute("COMMIT")

        } catch {

            try? database.execute("ROLLBACK")

            throw error
        }
    }
}
