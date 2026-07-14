import Foundation

// MARK: - StreamingJSONParser
// Reads a JSON array file one top-level object at a time.
// Never loads more than one card object into memory at once.

final class StreamingJSONParser {

    private let fileURL: URL
    private var fileHandle: FileHandle?
    private var buffer = Data()
    private var depth = 0
    private var inString = false
    private var escape = false
    private var finished = false
    private var cardsParsed = 0

    private let chunkSize = 65_536  // 64KB

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func open() throws {
        fileHandle = try FileHandle(forReadingFrom: fileURL)
        let found = skipToArrayStart()
        AppLog.debug("[Parser] Opened file: \(fileURL.lastPathComponent) | Found '[': \(found) | File size: \(fileSize())")
    }

    func close() {
        AppLog.debug("[Parser] Closed — parsed \(cardsParsed) cards total")
        try? fileHandle?.close()
        fileHandle = nil
        buffer.removeAll()
    }

    /// Returns the next card object, or nil at end of array.
    func nextCard() -> [String: Any]? {
        guard !finished, fileHandle != nil else { return nil }

        var objectBytes = Data()
        objectBytes.reserveCapacity(4096)

        while true {
            if buffer.isEmpty {
                guard let chunk = readChunk(), !chunk.isEmpty else {
                    finished = true
                    if cardsParsed == 0 { AppLog.debug("[Parser] ⚠️ Stream ended with 0 cards parsed") }
                    return nil
                }
                buffer = chunk
            }

            var i = buffer.startIndex
            while i < buffer.endIndex {
                let byte = buffer[i]

                if escape {
                    escape = false
                    objectBytes.append(byte)
                    i = buffer.index(after: i)
                    continue
                }

                if inString {
                    if byte == 0x5C { escape = true }
                    else if byte == 0x22 { inString = false }
                    objectBytes.append(byte)
                    i = buffer.index(after: i)
                    continue
                }

                switch byte {
                case 0x7B: // {

                    if cardsParsed == 0 {
                        AppLog.debug("[Parser] Found opening object")
                    }

                    depth += 1
                    objectBytes.append(byte)

                case 0x7D: // }
                    depth -= 1
                    objectBytes.append(byte)
                    if depth == 0 {
                        // Consumed one full object
                        buffer = Data(buffer[buffer.index(after: i)...])
                        let result = parseObject(objectBytes)
                        if result != nil { cardsParsed += 1 }
                        if cardsParsed == 1 { AppLog.debug("[Parser] ✅ First card parsed successfully") }
                        return result
                    }

                case 0x22: // "
                    inString = true
                    objectBytes.append(byte)

                case 0x5D: // ]

                    if depth == 0 {

                        finished = true
                        buffer.removeAll()

                        AppLog.debug(
                            "[Parser] Reached end of array after \(cardsParsed) cards"
                        )

                        return nil
                    }

                    if depth > 0 {
                        objectBytes.append(byte)
                    }

                default:
                    if depth > 0 { objectBytes.append(byte) }
                    // Outside objects: skip commas, whitespace, newlines
                }

                i = buffer.index(after: i)
            }

            buffer.removeAll()
        }
    }

    // MARK: - Private

    /// Reads forward until the opening `[` of the JSON array.
    /// Returns true if found, false if EOF reached first.
    private func skipToArrayStart() -> Bool {
        while true {
            guard let chunk = readChunk(), !chunk.isEmpty else {
                AppLog.debug("[Parser] ⚠️ EOF reached before finding '['")
                return false
            }
            for (i, byte) in chunk.enumerated() {
                if byte == 0x5B {

                    buffer = Data(chunk[(chunk.startIndex + i + 1)...])

                    let preview = String(
                        data: buffer.prefix(500),
                        encoding: .utf8
                    ) ?? "unable to decode"

                    AppLog.debug("========== FILE PREVIEW ==========")
                    AppLog.debug(preview)
                    AppLog.debug("==================================")

                    return true
                }
            }
        }
    }

    private func readChunk() -> Data? {
        guard let fh = fileHandle else { return nil }
        let data = fh.readData(ofLength: chunkSize)
        return data.isEmpty ? nil : data
    }

    private func parseObject(_ data: Data) -> [String: Any]? {
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            AppLog.debug("[Parser] Failed to parse object (\(data.count) bytes): \(error)")
            return nil
        }
    }

    private func fileSize() -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int64 else { return "unknown" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
