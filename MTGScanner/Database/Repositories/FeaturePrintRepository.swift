//
//  FeaturePrintRepository.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

struct FeaturePrintRecord: Hashable {

    let cardID: String
    let featurePrint: Data?
    let croppedFeaturePrint: Data?
    let fullFeaturePrint: Data?

    var hasAnyFeaturePrint: Bool {
        featurePrint != nil ||
        croppedFeaturePrint != nil ||
        fullFeaturePrint != nil
    }
}

enum FeaturePrintQueries {

    // MARK: - Schema

    static let createTable = """
    CREATE TABLE IF NOT EXISTS feature_prints (
        card_id TEXT PRIMARY KEY,
        feature_print BLOB,
        feature_print_cropped BLOB,
        feature_print_full BLOB
    );
    """

    // MARK: - Insert / Update

    static let upsert = """
    INSERT OR REPLACE INTO feature_prints (
        card_id,
        feature_print,
        feature_print_cropped,
        feature_print_full
    )
    VALUES (?, ?, ?, ?);
    """

    // MARK: - Fetch

    static let fetchByCardID = """
    SELECT
        card_id,
        feature_print,
        feature_print_cropped,
        feature_print_full
    FROM feature_prints
    WHERE card_id = ?
    LIMIT 1;
    """

    static let fetchAll = """
    SELECT
        card_id,
        feature_print,
        feature_print_cropped,
        feature_print_full
    FROM feature_prints;
    """

    static let exists = """
    SELECT EXISTS(
        SELECT 1
        FROM feature_prints
        WHERE card_id = ?
        LIMIT 1
    );
    """

    static let count = """
    SELECT COUNT(*)
    FROM feature_prints;
    """

    // MARK: - Delete

    static let deleteByCardID = """
    DELETE FROM feature_prints
    WHERE card_id = ?;
    """

    static let deleteAll = """
    DELETE FROM feature_prints;
    """
}

import SQLite3

final class FeaturePrintRepository {

    private let database: Database

    init(database: Database) {
        self.database = database
    }
}

// MARK: - Schema

extension FeaturePrintRepository {

    func createTableIfNeeded() throws {
        try database.execute(FeaturePrintQueries.createTable)
    }
}

// MARK: - Save

extension FeaturePrintRepository {

    func save(
        cardID: String,
        featurePrint: Data?,
        croppedFeaturePrint: Data?,
        fullFeaturePrint: Data?
    ) throws {

        let cleanedID = clean(cardID)

        guard !cleanedID.isEmpty else {
            return
        }

        let statement = try database.prepare(
            FeaturePrintQueries.upsert
        )

        defer {
            statement.finalize()
        }

        try statement.bind(cleanedID, at: 1)
        try bind(featurePrint, to: statement, at: 2)
        try bind(croppedFeaturePrint, to: statement, at: 3)
        try bind(fullFeaturePrint, to: statement, at: 4)

        try statement.execute()
    }

    func save(
        _ record: FeaturePrintRecord
    ) throws {

        try save(
            cardID: record.cardID,
            featurePrint: record.featurePrint,
            croppedFeaturePrint: record.croppedFeaturePrint,
            fullFeaturePrint: record.fullFeaturePrint
        )
    }
}

// MARK: - Fetch

extension FeaturePrintRepository {

    func featurePrint(
        for cardID: String
    ) throws -> FeaturePrintRecord? {

        let cleanedID = clean(cardID)

        guard !cleanedID.isEmpty else {
            return nil
        }

        let statement = try database.prepare(
            FeaturePrintQueries.fetchByCardID
        )

        defer {
            statement.finalize()
        }

        try statement.bind(cleanedID, at: 1)

        guard statement.step() else {
            return nil
        }

        return map(statement)
    }

    func allFeaturePrints() throws -> [FeaturePrintRecord] {

        let statement = try database.prepare(
            FeaturePrintQueries.fetchAll
        )

        defer {
            statement.finalize()
        }

        var records: [FeaturePrintRecord] = []

        while statement.step() {

            if let record = map(statement) {
                records.append(record)
            }
        }

        return records
    }
}

// MARK: - Exists / Count

extension FeaturePrintRepository {

    func exists(
        cardID: String
    ) throws -> Bool {

        let cleanedID = clean(cardID)

        guard !cleanedID.isEmpty else {
            return false
        }

        let statement = try database.prepare(
            FeaturePrintQueries.exists
        )

        defer {
            statement.finalize()
        }

        try statement.bind(cleanedID, at: 1)

        guard statement.step() else {
            return false
        }

        return statement.int(at: 0) == 1
    }

    func count() throws -> Int {

        let statement = try database.prepare(
            FeaturePrintQueries.count
        )

        defer {
            statement.finalize()
        }

        guard statement.step() else {
            return 0
        }

        return statement.int(at: 0)
    }
}

// MARK: - Delete

extension FeaturePrintRepository {

    func delete(
        cardID: String
    ) throws {

        let cleanedID = clean(cardID)

        guard !cleanedID.isEmpty else {
            return
        }

        let statement = try database.prepare(
            FeaturePrintQueries.deleteByCardID
        )

        defer {
            statement.finalize()
        }

        try statement.bind(cleanedID, at: 1)

        try statement.execute()
    }

    func deleteAll() throws {
        try database.execute(FeaturePrintQueries.deleteAll)
    }
}

// MARK: - Mapping

private extension FeaturePrintRepository {

    func map(
        _ statement: SQLiteStatement
    ) -> FeaturePrintRecord? {

        guard let cardID = statement.string(at: 0) else {
            return nil
        }

        return FeaturePrintRecord(
            cardID: cardID,
            featurePrint: statement.data(at: 1),
            croppedFeaturePrint: statement.data(at: 2),
            fullFeaturePrint: statement.data(at: 3)
        )
    }
}

// MARK: - Binding Helpers

private extension FeaturePrintRepository {

    func bind(
        _ data: Data?,
        to statement: SQLiteStatement,
        at index: Int
    ) throws {

        guard let data else {
            sqlite3_bind_null(
                statement.statementPointer,
                Int32(index)
            )
            return
        }

        try statement.bind(
            data,
            at: index
        )
    }
}

// MARK: - Helpers

private extension FeaturePrintRepository {

    func clean(
        _ value: String
    ) -> String {

        value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }
}
