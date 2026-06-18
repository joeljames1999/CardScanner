import Foundation
import SQLite3

final class CardDatabaseService {

    static let shared = CardDatabaseService()

    var db: OpaquePointer?
    var insertStmt: OpaquePointer?

    let databaseQueue = DispatchQueue(
        label: "com.tcgcompanion.database"
    )

    let schemaVersion = 8

    let dbURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true
        )

        return appSupport.appendingPathComponent(
            "scryfall_cards.sqlite"
        )
    }()

    private init() {
        openDatabase()
        migrateIfNeeded()
        prepareInsertStatement()
    }
}
