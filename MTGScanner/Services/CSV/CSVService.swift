//
//  CSVService.swift
//  TcgScanner
//
//  Created by Joel James on 03/07/2026.
//

import Foundation

final class CSVService {

    static let shared = CSVService()

    private let importer = CSVImporter()
    private let exporter = CSVExporter()

    private init() {}

    // MARK: - Export

    func export(
        _ entries: [CollectionEntry],
        format: CSVFormat = .moxfield
    ) -> String {

        exporter.export(
            entries: entries
        )
    }

    func saveToFile(
        _ entries: [CollectionEntry],
        format: CSVFormat = .moxfield
    ) -> URL? {

        let csv = export(
            entries,
            format: format
        )

        let filename = "mtg_collection_\(datestamp()).csv"

        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(filename)

        do {

            try csv.write(
                to: url,
                atomically: true,
                encoding: .utf8
            )

            return url

        } catch {

            print("[CSV] Failed to save:", error)
            return nil
        }
    }

    // MARK: - Import

    func importCSV(
        _ csv: String
    ) -> CSVImportResult {

        return importer.importCSV(csv)
    }

    func importFile(at url: URL) -> CSVImportResult {

        print("Reading:", url)

        do {

            let data = try Data(contentsOf: url)
            print("Read \(data.count) bytes")

            let csv = String(decoding: data, as: UTF8.self)

            print("CSV preview:")
            print(csv.prefix(200))

            return importer.importCSV(csv)

        } catch {

            print("READ FAILED:", error)

            return CSVImportResult(
                entries: [],
                skippedRows: 0,
                errors: [error.localizedDescription]
            )
        }
    }
    
//    func importFile(
//        at url: URL
//    ) -> CSVImportResult {
//
//        do {
//
//            let csv = try String(
//                contentsOf: url,
//                encoding: .utf8
//            )
//
//            return importer.importCSV(csv)
//
//        } catch {
//
//            return CSVImportResult(
//                entries: [],
//                skippedRows: 0,
//                errors: [error.localizedDescription]
//            )
//        }
//    }

    // MARK: - Helpers

    private func datestamp() -> String {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"

        return formatter.string(from: Date())
    }
}
