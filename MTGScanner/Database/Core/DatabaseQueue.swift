//
//  DatabaseQueue.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

final class DatabaseQueue {

    static let shared = DatabaseQueue()

    private let queue = DispatchQueue(
        label: "com.cardscanner.database",
        qos: .userInitiated
    )

    private(set) var database: Database!

    private init() {}

    func configure(database: Database) {
        self.database = database
    }

    @discardableResult
    func read<T>(
        _ block: (Database) throws -> T
    ) rethrows -> T {

        try queue.sync {

            try block(database)

        }
    }

    @discardableResult
    func write<T>(
        _ block: (Database) throws -> T
    ) rethrows -> T {

        try queue.sync {

            try block(database)

        }
    }

    @discardableResult
    func transaction<T>(
        _ block: (Database) throws -> T
    ) throws -> T {

        try queue.sync {

            try database.execute("BEGIN IMMEDIATE")

            do {

                let result = try block(database)

                try database.execute("COMMIT")

                return result

            } catch {

                try? database.execute("ROLLBACK")

                throw error
            }
        }
    }
}
