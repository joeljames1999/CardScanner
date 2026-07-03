//
//  CSVImportResult.swift
//  TcgScanner
//
//  Created by Joel James on 03/07/2026.
//

import Foundation

struct CSVImportResult {

    let entries: [CollectionEntry]

    let skippedRows: Int

    let errors: [String]

    var importedRows: Int {
        entries.count
    }

    var hasErrors: Bool {
        !errors.isEmpty
    }
}
