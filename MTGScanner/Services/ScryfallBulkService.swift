import Foundation
import UIKit

// MARK: - ScryfallBulkService
// Downloads Scryfall unique_artwork bulk data and builds a local SQLite index.
//
// Memory strategy:
// - JSON downloaded directly to a temp file (never in RAM)
// - StreamingJSONParser reads one card at a time (one object in memory at once)
// - Cards written to SQLite in batches of 100 then released
// - Art images downloaded 10 at a time, hashed, and immediately released
// - Peak RAM usage: ~10 art images (~1MB) + 100 card dicts (~500KB) = ~2MB max

final class ScryfallBulkService: NSObject, ObservableObject {

    static let shared = ScryfallBulkService()

    private let bulkMetaURL    = URL(string: "https://api.scryfall.com/bulk-data")!
    private let lastUpdatedKey = "ScryfallBulkLastUpdated"
    private let staleness: TimeInterval = 60 * 60 * 24 // 24 hours

    // MARK: - Download State

    enum DownloadState: Equatable {
        case idle
        case fetchingManifest
        case downloading(progress: Double, totalBytes: Int64)
        case importing(done: Int, total: Int)
        case hashingArt(done: Int, total: Int)
        case done
        case failed(String)
    }

    @Published private(set) var downloadState: DownloadState = .idle

    // URLSession download delegate plumbing
    private var downloadContinuation: CheckedContinuation<URL, Error>?
    private var expectedBytes: Int64 = 0

    private override init() {}

    // MARK: - Public

    var isDataPresent: Bool { !CardDatabaseService.shared.isEmpty }

    var dataSizeOnDisk: String {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scryfall_cards.sqlite")
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int64
        else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var lastUpdatedDate: Date? {
        UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date
    }

    var lastUpdatedString: String {
        guard let date = lastUpdatedDate else { return "Never" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    var artHashCount: Int { CardDatabaseService.shared.artHashCount }

    func refreshIfNeeded() async {
        guard !isDownloading else { return }
        if CardDatabaseService.shared.isEmpty || isStale {
            await downloadAndImport()
        } else {
            print("[Bulk] Data is fresh, skipping download.")
        }
    }

    func forceRefresh() async {
        guard !isDownloading else { return }
        await downloadAndImport()
    }

    private var isDownloading: Bool {
        switch downloadState {
        case .idle, .done, .failed: return false
        default: return true
        }
    }

    private var isStale: Bool {
        guard let last = lastUpdatedDate else { return true }
        return Date().timeIntervalSince(last) > staleness
    }

    // MARK: - Pipeline

    private func downloadAndImport() async {
        do {
            // 1. Get the download URL from the manifest
            await setState(.fetchingManifest)
            let (uri, remoteSize) = try await fetchManifest(type: "unique_artwork")

            // 2. Download JSON to a temp file — never touches RAM
            await setState(.downloading(progress: 0, totalBytes: remoteSize))
            let tempFile = try await downloadToFile(from: uri, expectedSize: remoteSize)
            defer { try? FileManager.default.removeItem(at: tempFile) }

            // 3. Stream-parse and import cards one at a time
            let total = try await streamImport(from: tempFile)

            // 4. Stream-parse again to hash art, 10 at a time
            try await streamHashArt(from: tempFile, totalCards: total)

            UserDefaults.standard.set(Date(), forKey: lastUpdatedKey)
            await setState(.done)

        } catch {
            await setState(.failed(error.localizedDescription))
            print("[Bulk] Failed: \(error)")
        }
    }

    // MARK: - Stream Import
    // Reads one card at a time, batches 100 at a time into SQLite, then releases.
    // Peak memory: ~100 card dicts at once (~500KB)

    private func streamImport(from fileURL: URL) async throws -> Int {
        await setState(.importing(done: 0, total: 0))

        return try await Task.detached(priority: .userInitiated) {
            let parser = StreamingJSONParser(fileURL: fileURL)
            try parser.open()
            defer { parser.close() }

            let db = CardDatabaseService.shared
            var batch: [[String: Any]] = []
            batch.reserveCapacity(100)
            var total = 0

            // Clear existing data before import
            db.clearCards()

            while let card = parser.nextCard() {
                batch.append(card)
                total += 1

                if batch.count >= 100 {
                    db.importCards(batch)
                    batch.removeAll(keepingCapacity: true)

                    await MainActor.run {
                        self.downloadState = .importing(done: total, total: 0)
                    }
                }
            }

            // Flush remaining
            if !batch.isEmpty {
                db.importCards(batch)
            }

            print("[Bulk] Imported \(total) cards via streaming.")
            return total
        }.value
    }

    // MARK: - Stream Hash Art
    // Reads card IDs + art URLs from file, downloads 10 images at a time,
    // hashes each, stores the UInt64, immediately releases image data.
    // Peak memory: ~10 images * ~100KB each = ~1MB

    private func streamHashArt(from fileURL: URL, totalCards: Int) async throws {
        let db = CardDatabaseService.shared

        // Pass 1: collect (id, artURL) pairs — just two strings per card, very cheap
        let workList: [(id: String, url: URL)] = try await Task.detached(priority: .userInitiated) {
            let parser = StreamingJSONParser(fileURL: fileURL)
            try parser.open()
            defer { parser.close() }

            var result: [(String, URL)] = []
            result.reserveCapacity(totalCards)

            while let card = parser.nextCard() {
                guard let id = card["id"] as? String,
                      !db.hasArtHash(oracleId: id)
                else { continue }

                // Try top-level image_uris first, then card_faces for DFCs
                let artURLString: String? = {
                    if let uris = card["image_uris"] as? [String: String] {
                        return uris["art_crop"] ?? uris["normal"]
                    }
                    if let faces = card["card_faces"] as? [[String: Any]],
                       let uris  = faces.first?["image_uris"] as? [String: String] {
                        return uris["art_crop"] ?? uris["normal"]
                    }
                    return nil
                }()

                if let raw = artURLString, let url = URL(string: raw) {
                    result.append((id, url))
                }
            }
            return result
        }.value

        let total = workList.count
        guard total > 0 else {
            print("[Bulk] All \(db.artHashCount) art hashes already present.")
            return
        }

        print("[Bulk] Hashing \(total) artworks…")
        await setState(.hashingArt(done: 0, total: total))

        let artService = ArtHashService.shared
        let batchSize  = 10  // low concurrency = low memory
        var done       = 0

        for batchStart in stride(from: 0, to: total, by: batchSize) {
            let batch = Array(workList[batchStart ..< min(batchStart + batchSize, total)])

            // All tasks in this group complete before we move to the next batch.
            // Each UIImage + crop is released as soon as its task finishes.
            await withTaskGroup(of: Void.self) { group in
                for item in batch {
                    group.addTask {
                        // Entire pipeline in one closure — nothing escapes
                        guard
                            let (data, _) = try? await URLSession.shared.data(from: item.url),
                            let image = UIImage(data: data),
                            let crop  = artService.cropArtRegion(from: image),
                            let hash  = artService.pHash(of: crop)
                        else { return }

                        // Store the 8-byte hash, release everything else
                        db.storeArtHash(oracleId: item.id, hash: hash)
                        // image, crop, data all go out of scope here
                    }
                }
            }
            // All 10 images fully released here before next batch

            done = min(batchStart + batchSize, total)
            await setState(.hashingArt(done: done, total: total))

            // Yield to allow ARC/system to reclaim memory between batches
            await Task.yield()
        }

        print("[Bulk] Hashing complete — \(db.artHashCount) hashes stored.")
    }

    // MARK: - Manifest

    private func fetchManifest(type: String) async throws -> (URL, Int64) {
        var req = URLRequest(url: bulkMetaURL)
        req.setValue("MTGScanner-iOS/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)

        guard
            let json      = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataArray = json["data"] as? [[String: Any]],
            let bulk      = dataArray.first(where: { $0["type"] as? String == type }),
            let uriStr    = bulk["download_uri"] as? String,
            let uri       = URL(string: uriStr)
        else { throw URLError(.cannotParseResponse) }

        let size = bulk["size"] as? Int64 ?? bulk["compressed_size"] as? Int64 ?? 0
        return (uri, size)
    }

    // MARK: - Download to File
    // Uses URLSessionDownloadTask which writes directly to disk.
    // The JSON data never enters RAM.

    private func downloadToFile(from url: URL, expectedSize: Int64) async throws -> URL {
        self.expectedBytes = expectedSize
        return try await withCheckedThrowingContinuation { continuation in
            self.downloadContinuation = continuation
            var req = URLRequest(url: url)
            req.setValue("MTGScanner-iOS/1.0", forHTTPHeaderField: "User-Agent")
            req.timeoutInterval = 300 // 5 min timeout for large file
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            session.downloadTask(with: req).resume()
        }
    }

    private func setState(_ state: DownloadState) async {
        await MainActor.run { downloadState = state }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ScryfallBulkService: URLSessionDownloadDelegate {

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Move from ephemeral temp location to a stable path we control
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("scryfall_\(UUID().uuidString).json")
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            downloadContinuation?.resume(returning: dest)
        } catch {
            downloadContinuation?.resume(throwing: error)
        }
        downloadContinuation = nil
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : expectedBytes
        let progress = expected > 0 ? Double(totalBytesWritten) / Double(expected) : 0

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
        if let error = error {
            downloadContinuation?.resume(throwing: error)
            downloadContinuation = nil
        }
    }
}
