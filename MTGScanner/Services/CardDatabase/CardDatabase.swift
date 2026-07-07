import Foundation
import SQLite3

final class CardDatabaseService {
    
    static let shared = CardDatabaseService()
    
    var db: OpaquePointer?
    var insertStmt: OpaquePointer?
    
    let databaseQueue = DispatchQueue(
        label: "com.tcgcompanion.database"
    )
    
    let SQLITE_TRANSIENT = unsafeBitCast(
        -1,
        to: sqlite3_destructor_type.self
    )
    
    let schemaVersion = 5
    
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
    
    func loadLookupCards() -> [CardLookup] {
        
        var results: [CardLookup] = []
        
        let sql = """
        SELECT
            id,
            name,
            set_code,
            collector_number
        FROM cards
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(
            db,
            sql,
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            
            return []
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            
            guard
                let id = sqlite3_column_text(statement, 0),
                let name = sqlite3_column_text(statement, 1),
                let set = sqlite3_column_text(statement, 2),
                let collector = sqlite3_column_text(statement, 3)
            else {
                continue
            }
            
            results.append(
                
                CardLookup(
                    
                    id: String(cString: id),
                    
                    name: String(cString: name),
                    
                    set: String(cString: set),
                    
                    collectorNumber: String(cString: collector)
                )
            )
        }
        
        return results
    }
}
