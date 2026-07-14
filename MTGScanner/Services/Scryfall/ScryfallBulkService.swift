import Foundation
import UIKit
import Compression

//
//  ScryfallBulkService.swift
//  TcgScanner
//

import Foundation
import Compression

final class ScryfallBulkService: NSObject, ObservableObject {

    static let shared = ScryfallBulkService()

    private let bulkMetaURL =
        URL(string: "https://api.scryfall.com/bulk-data")!

    private let lastUpdatedKey = "ScryfallBulkLastUpdated"

    private let staleness: TimeInterval =
        60 * 60 * 24

    // MARK: - State

    enum DownloadState: Equatable {

        case idle

        case fetchingManifest

        case downloading(
            progress: Double,
            totalBytes: Int64
        )

        case importing(
            done: Int,
            total: Int
        )

        case done

        case failed(String)
    }

    @Published private(set) var downloadState: DownloadState = .idle

    private var downloadContinuation: CheckedContinuation<URL, Error>?

    private var expectedBytes: Int64 = 0

    private var downloadSession: URLSession?

    private override init() {}

    // MARK: - Public

    var isDataPresent: Bool {

        do {
            return try AppDatabase.shared
                .bulkImport
                .countCards() > 0
        } catch {
            return false
        }
    }

    var dataSizeOnDisk: String {

        let url = FileManager.default
            .urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            .appendingPathComponent(
                "scryfall_cards.sqlite"
            )

        guard
            let size = try? FileManager.default
                .attributesOfItem(
                    atPath: url.path
                )[.size] as? Int64
        else {
            return "Unknown"
        }

        return ByteCountFormatter.string(
            fromByteCount: size,
            countStyle: .file
        )
    }

    var lastUpdatedDate: Date? {

        UserDefaults.standard.object(
            forKey: lastUpdatedKey
        ) as? Date
    }

    var lastUpdatedString: String {

        guard let date = lastUpdatedDate else {
            return "Never"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full

        return formatter.localizedString(
            for: date,
            relativeTo: Date()
        )
    }

    func refreshIfNeeded() async {

        guard !isDownloading else {
            return
        }

        if !isDataPresent || isStale {
            await downloadAndImport()
        } else {
            AppLog.debug("[Bulk] Data is fresh, skipping download.")
            await setState(.done)
        }
    }

    func forceRefresh() async {

        guard !isDownloading else {
            return
        }

        await downloadAndImport()
    }
}

// MARK: - State Helpers

private extension ScryfallBulkService {

    var isDownloading: Bool {

        switch downloadState {

        case .idle,
             .done,
             .failed:
            return false

        case .fetchingManifest,
             .downloading,
             .importing:
            return true
        }
    }

    var isStale: Bool {

        guard let last = lastUpdatedDate else {
            return true
        }

        return Date().timeIntervalSince(last) > staleness
    }

    func setState(
        _ state: DownloadState
    ) async {

        await MainActor.run {
            self.downloadState = state
        }
    }
}

// MARK: - Pipeline

private extension ScryfallBulkService {

    func downloadAndImport() async {

        do {

            await setState(.fetchingManifest)

            let manifest = try await fetchManifest(
                type: "default_cards"
            )

            await setState(
                .downloading(
                    progress: 0,
                    totalBytes: manifest.remoteSize
                )
            )

            let rawFile = try await downloadToFile(
                from: manifest.url,
                expectedSize: manifest.remoteSize
            )

            defer {
                try? FileManager.default.removeItem(
                    at: rawFile
                )
            }

            let jsonFile = try decompressIfNeeded(
                rawFile
            )

            defer {

                if jsonFile != rawFile {
                    try? FileManager.default.removeItem(
                        at: jsonFile
                    )
                }
            }

            try verifyIsJSON(
                jsonFile
            )

            let result = try await importDatabase(
                from: jsonFile
            )

            UserDefaults.standard.set(
                Date(),
                forKey: lastUpdatedKey
            )

            await setState(.done)

            await MainActor.run {

                NotificationCenter.default.post(
                    name: .cardDatabaseDidChange,
                    object: nil
                )
            }

            AppLog.debug(
                "[Bulk] Import complete. Inserted \(result.insertedCount), skipped \(result.skippedCount), database count \(result.databaseCount)."
            )

        } catch {

            await setState(
                .failed(error.localizedDescription)
            )

            AppLog.debug("[Bulk] Failed:", error)
        }
    }

    func importDatabase(
        from fileURL: URL
    ) async throws -> BulkImportResult {

        await setState(
            .importing(
                done: 0,
                total: 115_000
            )
        )

        return try await Task.detached(
            priority: .userInitiated
        ) {

            try AppDatabase.shared.bulkImport.importCards(
                fromFileAt: fileURL
            ) { progress in

                Task { @MainActor in

                    self.downloadState = .importing(
                        done: progress.processed,
                        total: progress.total
                    )
                }
            }

        }.value
    }
}

// MARK: - Manifest

private extension ScryfallBulkService {

    func fetchManifest(
        type: String
    ) async throws -> (
        url: URL,
        remoteSize: Int64
    ) {

        var request = URLRequest(
            url: bulkMetaURL
        )

        request.setValue(
            "TCGCompanion-iOS/1.0",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, _) = try await URLSession.shared.data(
            for: request
        )

        guard
            let json = try JSONSerialization
                .jsonObject(with: data) as? [String: Any],
            let dataArray = json["data"] as? [[String: Any]],
            let bulk = dataArray.first(
                where: {
                    $0["type"] as? String == type
                }
            ),
            let uriString = bulk["download_uri"] as? String,
            let uri = URL(string: uriString)
        else {
            throw URLError(.cannotParseResponse)
        }

        let size =
            bulk["size"] as? Int64 ??
            bulk["compressed_size"] as? Int64 ??
            0

        return (
            url: uri,
            remoteSize: size
        )
    }

    func downloadToFile(
        from url: URL,
        expectedSize: Int64
    ) async throws -> URL {

        self.expectedBytes = expectedSize

        return try await withCheckedThrowingContinuation {
            continuation in

            self.downloadContinuation = continuation

            var request = URLRequest(url: url)

            request.setValue(
                "TCGCompanion-iOS/1.0",
                forHTTPHeaderField: "User-Agent"
            )

            request.setValue(
                "identity",
                forHTTPHeaderField: "Accept-Encoding"
            )

            request.timeoutInterval = 300

            let session = URLSession(
                configuration: .default,
                delegate: self,
                delegateQueue: nil
            )

            self.downloadSession = session

            session.downloadTask(
                with: request
            ).resume()
        }
    }
}
// MARK: - File Preparation

private extension ScryfallBulkService {

    func decompressIfNeeded(
        _ fileURL: URL
    ) throws -> URL {

        guard
            let handle = FileHandle(
                forReadingAtPath: fileURL.path
            )
        else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        let magic = handle.readData(
            ofLength: 2
        )

        handle.closeFile()

        let isGzip =
            magic.count >= 2 &&
            magic[0] == 0x1F &&
            magic[1] == 0x8B

        guard isGzip else {

            AppLog.debug(
                "[Bulk] File is plain JSON — no decompression needed."
            )

            return fileURL
        }

        AppLog.debug("[Bulk] Gzip detected — decompressing…")

        let compressedData = try Data(
            contentsOf: fileURL
        )

        let decompressed =
            try (compressedData as NSData)
                .decompressed(using: .zlib) as Data

        let destination = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "scryfall_decompressed_\(UUID().uuidString).json"
            )

        try decompressed.write(
            to: destination,
            options: .atomic
        )

        AppLog.debug(
            "[Bulk] Decompressed: \(ByteCountFormatter.string(fromByteCount: Int64(decompressed.count), countStyle: .file))"
        )

        return destination
    }

    func verifyIsJSON(
        _ fileURL: URL
    ) throws {

        guard
            let handle = FileHandle(
                forReadingAtPath: fileURL.path
            )
        else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        defer {
            handle.closeFile()
        }

        let peek = handle.readData(
            ofLength: 64
        )

        for byte in peek {

            if byte == 0x20 ||
                byte == 0x0A ||
                byte == 0x0D ||
                byte == 0x09 {
                continue
            }

            if byte == 0x5B {
                AppLog.debug("[Bulk] ✅ File verified as JSON array.")
                return
            }

            throw NSError(
                domain: "ScryfallBulkService",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "File is not valid JSON. First byte: 0x\(String(byte, radix: 16))"
                ]
            )
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ScryfallBulkService: URLSessionDownloadDelegate {

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {

        let destination = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "scryfall_raw_\(UUID().uuidString).bin"
            )

        do {

            try FileManager.default.moveItem(
                at: location,
                to: destination
            )

            downloadContinuation?.resume(
                returning: destination
            )

        } catch {

            downloadContinuation?.resume(
                throwing: error
            )
        }

        downloadContinuation = nil

        session.finishTasksAndInvalidate()

        downloadSession = nil
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {

        let expected =
            totalBytesExpectedToWrite > 0
            ? totalBytesExpectedToWrite
            : expectedBytes

        let progress =
            expected > 0
            ? Double(totalBytesWritten) / Double(expected)
            : 0

        Task { @MainActor in

            self.downloadState = .downloading(
                progress: min(progress, 1.0),
                totalBytes: expected
            )
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {

        guard let error else {
            return
        }

        downloadContinuation?.resume(
            throwing: error
        )

        downloadContinuation = nil

        session.finishTasksAndInvalidate()

        downloadSession = nil
    }
}

extension Notification.Name {

    static let cardDatabaseDidChange =
        Notification.Name("cardDatabaseDidChange")
}
