//
//  DatabaseError.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

enum DatabaseError: LocalizedError {

    case notOpen

    case openFailed(String)

    case sqlite(String)

    case prepareFailed(String)

    case stepFailed(String)

    case bindFailed

    var errorDescription: String? {

        switch self {

        case .notOpen:
            return "Database is not open."

        case .openFailed(let message):
            return "Unable to open database.\n\(message)"

        case .sqlite(let message):
            return message

        case .prepareFailed(let message):
            return "Failed to prepare statement.\n\(message)"

        case .stepFailed(let message):
            return "SQLite step failed.\n\(message)"

        case .bindFailed:
            return "Failed to bind SQLite values."
        }
    }
}
