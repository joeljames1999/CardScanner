//
//  CardDatabase+FeaturePrints.swift
//  TcgScanner
//
//  Created by Joel James on 17/06/2026.
//

/*
 7. CardDatabase+FeaturePrints.swift

 Move:

 storeFeaturePrint()
 allFeaturePrints()
 featurePrintCount()
 generateFeaturePrint()

 into here.
 */

import Foundation
import SQLite3
import Vision

extension CardDatabaseService {

    func storeFeaturePrint(
        cardId: String,
        data: Data
    ) {

        print("[Vision] Attempting save:", cardId)

        let sql = """
        INSERT OR REPLACE INTO feature_prints
        (card_id, feature_print)
        VALUES (?, ?);
        """

        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(
            db,
            sql,
            -1,
            &stmt,
            nil
        ) == SQLITE_OK else {

            print(
                "[Vision] Prepare failed:",
                String(cString: sqlite3_errmsg(db))
            )

            return
        }

        defer {
            sqlite3_finalize(stmt)
        }

        let TRANSIENT =
            unsafeBitCast(
                -1,
                to: sqlite3_destructor_type.self
            )

        sqlite3_bind_text(
            stmt,
            1,
            cardId,
            -1,
            TRANSIENT
        )

        data.withUnsafeBytes { buffer in
            sqlite3_bind_blob(
                stmt,
                2,
                buffer.baseAddress,
                Int32(data.count),
                TRANSIENT
            )
        }

        let result = sqlite3_step(stmt)

        if result == SQLITE_DONE {

            print(
                "[Vision] Saved:",
                cardId
            )

        } else {

            print(
                "[Vision] Save failed:",
                result,
                String(cString: sqlite3_errmsg(db))
            )
        }
    }
    
    func allFeaturePrints()
    -> [(String, Data)] {

        var results: [(String, Data)] = []

        let sql =
        """
        SELECT card_id, feature_print
        FROM feature_prints
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

        while sqlite3_step(stmt) == SQLITE_ROW {

            guard
                let idPtr = sqlite3_column_text(stmt, 0)
            else {
                continue
            }

            let cardID =
                String(cString: idPtr)

            let bytes =
                sqlite3_column_blob(stmt, 1)

            let size =
                sqlite3_column_bytes(stmt, 1)

            let data =
                Data(
                    bytes: bytes!,
                    count: Int(size)
                )

            results.append(
                (cardID, data)
            )
        }

        return results
    }
    
    func generateFeaturePrint(from observation: VNFeaturePrintObservation) throws -> Data {
        return try NSKeyedArchiver.archivedData(
            withRootObject: observation,
            requiringSecureCoding: true
        )
    }
    
    func featurePrintCount() -> Int {

        databaseQueue.sync {

            var stmt: OpaquePointer?

            let sql = """
            SELECT COUNT(*)
            FROM feature_prints;
            """

            guard sqlite3_prepare_v2(
                db,
                sql,
                -1,
                &stmt,
                nil
            ) == SQLITE_OK else {

                print(
                    "[CardDB] featurePrintCount failed:",
                    String(cString: sqlite3_errmsg(db))
                )

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
    
    func saveFeaturePrint(cardId: String, observation: VNFeaturePrintObservation) {
        let sql = "INSERT OR REPLACE INTO feature_prints (card_id, print_blob) VALUES (?, ?);"
        var stmt: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        
        // Serialize VNFeaturePrintObservation to binary Data
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true) else {
            sqlite3_finalize(stmt)
            return
        }
        
        let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, cardId, -1, TRANSIENT)
        
        data.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, 2, bytes.baseAddress, Int32(data.count), TRANSIENT)
        }
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[CardDB] Failed to save feature print blob")
        }
        sqlite3_finalize(stmt)
    }

    func fetchFeaturePrints(for cardIds: [String]) -> [String: VNFeaturePrintObservation] {
        guard !cardIds.isEmpty else { return [:] }
        
        // Dynamically build placeholder markers: ?, ?, ?
        let placeholders = String(repeating: "?,", count: cardIds.count).dropLast()
        let sql = "SELECT card_id, print_blob FROM feature_prints WHERE card_id IN (\(placeholders));"
        
        var stmt: OpaquePointer?
        var results: [String: VNFeaturePrintObservation] = [:]
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        
        let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, id) in cardIds.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), id, -1, TRANSIENT)
        }
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cString = sqlite3_column_text(stmt, 0) {
                let cardId = String(cString: cString)
                if let blobBytes = sqlite3_column_blob(stmt, 1) {
                    let blobSize = sqlite3_column_bytes(stmt, 1)
                    let data = Data(bytes: blobBytes, count: Int(blobSize))
                    
                    if let observation = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data) {
                        results[cardId] = observation
                    }
                }
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
}
