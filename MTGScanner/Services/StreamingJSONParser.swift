import Foundation

// MARK: - StreamingJSONParser
// Reads a JSON array file one top-level object at a time.
// Never loads more than one card object into memory at once.
// Specifically designed for the Scryfall bulk data format: [{...},{...},...]

final class StreamingJSONParser {

    private let fileURL: URL
    private var fileHandle: FileHandle?
    private var buffer = Data()
    private var depth = 0
    private var inString = false
    private var escape = false
    private var started = false    // found the opening [
    private var finished = false

    private let chunkSize = 65_536  // 64KB read chunks — small RAM footprint

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func open() throws {
        fileHandle = try FileHandle(forReadingFrom: fileURL)
        // Skip the opening [ by reading until we find it
        skipToArrayStart()
    }

    func close() {
        try? fileHandle?.close()
        fileHandle = nil
        buffer.removeAll()
    }

    /// Returns the next card object as a dictionary, or nil at end of array.
    /// Call repeatedly until nil is returned.
    func nextCard() -> [String: Any]? {
        guard !finished else { return nil }

        var objectBytes = Data()
        objectBytes.reserveCapacity(4096)

        while true {
            // Refill buffer if empty
            if buffer.isEmpty {
                guard let chunk = readChunk(), !chunk.isEmpty else {
                    finished = true
                    return nil
                }
                buffer = chunk
            }

            // Process bytes one at a time to track object boundaries
            var i = buffer.startIndex
            while i < buffer.endIndex {
                let byte = buffer[i]
                let char = Character(UnicodeScalar(byte))

                if escape {
                    escape = false
                    objectBytes.append(byte)
                    i = buffer.index(after: i)
                    continue
                }

                if inString {
                    if byte == 0x5C { // backslash
                        escape = true
                    } else if byte == 0x22 { // quote
                        inString = false
                    }
                    objectBytes.append(byte)
                    i = buffer.index(after: i)
                    continue
                }

                switch char {
                case "{":
                    depth += 1
                    objectBytes.append(byte)
                case "}":
                    depth -= 1
                    objectBytes.append(byte)
                    if depth == 0 {
                        // Consumed one full card object
                        buffer = Data(buffer[buffer.index(after: i)...])
                        return parseObject(objectBytes)
                    }
                case "\"":
                    inString = true
                    objectBytes.append(byte)
                case "]":
                    // End of array
                    finished = true
                    buffer.removeAll()
                    return nil
                default:
                    if depth > 0 {
                        objectBytes.append(byte)
                    }
                    // Outside objects: skip commas, whitespace, newlines between cards
                }

                i = buffer.index(after: i)
            }

            // Consumed all of buffer — loop to read more
            buffer.removeAll()
        }
    }

    // MARK: - Private

    private func skipToArrayStart() {
        // Read until we find the '[' that opens the card array
        while true {
            guard let chunk = readChunk(), !chunk.isEmpty else { return }
            for (i, byte) in chunk.enumerated() {
                if byte == 0x5B { // [
                    // Keep everything after the [
                    buffer = Data(chunk[(chunk.startIndex + i + 1)...])
                    return
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
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
