import Foundation

// MARK: - CSV Service
// Exports and imports in Moxfield format, which is also compatible with
// Archidekt, Deckbox, and most other MTG collection tools.
//
// Moxfield CSV columns:
// Count, Tradelist Count, Name, Edition, Condition, Language, Foil, Tags, Last Modified, Collector Number, Alter, Proxy, Purchase Price

final class CSVService {

    static let shared = CSVService()
    private init() {}

    // MARK: - Export

    func export(_ entries: [CollectionEntry]) -> String {
        var rows: [String] = [moxfieldHeader]

        for entry in entries {
            let row = moxfieldRow(for: entry)
            rows.append(row)
        }

        return rows.joined(separator: "\n")
    }

    private var moxfieldHeader: String {
        "Count,Tradelist Count,Name,Edition,Condition,Language,Foil,Tags,Last Modified,Collector Number,Alter,Proxy,Purchase Price"
    }

    private func moxfieldRow(for entry: CollectionEntry) -> String {
        let lastModified = ISO8601DateFormatter().string(from: entry.dateAdded)
        let purchasePrice = entry.purchasePrice.map { String(format: "%.2f", $0) } ?? ""
        let foil = entry.isFoil ? "foil" : ""

        return [
            String(entry.count),
            "0",                           // Tradelist count (not in scope)
            csvEscape(entry.name),
            entry.setCode.uppercased(),
            entry.condition.moxfieldCode,
            entry.language,
            foil,
            "",                            // Tags
            lastModified,
            entry.collectorNumber,
            "FALSE",                       // Alter
            "FALSE",                       // Proxy
            purchasePrice
        ].joined(separator: ",")
    }

    // MARK: - Import

    struct ImportResult {
        let entries: [CollectionEntry]
        let skippedRows: Int
        let errors: [String]
    }

    func importCSV(_ csvString: String, existingCards: [MTGCard] = []) -> ImportResult {
        var entries: [CollectionEntry] = []
        var skipped = 0
        var errors: [String] = []

        let lines = csvString.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else {
            return ImportResult(entries: [], skippedRows: 0, errors: ["File appears empty"])
        }

        // Skip header row
        for (index, line) in lines.dropFirst().enumerated() {
            let cols = parseCSVLine(line)

            guard cols.count >= 4 else {
                skipped += 1
                errors.append("Row \(index + 2): not enough columns")
                continue
            }

            guard let count = Int(cols[0].trimmingCharacters(in: .whitespaces)), count > 0 else {
                skipped += 1
                continue
            }

            let name      = cols[2].trimmingCharacters(in: .whitespaces)
            let setCode   = cols.count > 3 ? cols[3].trimmingCharacters(in: .whitespaces) : ""
            let condition = cols.count > 4 ? CardCondition.fromMoxfield(cols[4]) : .nearMint
            let language  = cols.count > 5 ? cols[5].trimmingCharacters(in: .whitespaces) : "English"
            let isFoil    = cols.count > 6 ? cols[6].lowercased().contains("foil") : false
            let collectorNumber = cols.count > 9 ? cols[9].trimmingCharacters(in: .whitespaces) : ""
            let purchasePrice   = cols.count > 12 ? Double(cols[12].trimmingCharacters(in: .whitespaces)) : nil
            let isAltered = cols.count > 13 ? cols[13].lowercased().contains("altered") : false

            guard !name.isEmpty else {
                skipped += 1
                continue
            }

            // Build a synthetic CollectionEntry from CSV data
            let entry = CollectionEntry(
                id: UUID(),
                count: count,
                cardID: UUID().uuidString,   // placeholder — no Scryfall ID in CSV
                name: name,
                setCode: setCode.lowercased(),
                setName: setCode.uppercased(),
                collectorNumber: collectorNumber,
                rarity: "unknown",
                condition: condition,
                isFoil: isFoil,
                language: language,
                purchasePrice: purchasePrice,
                usdPrice: purchasePrice.map { String($0) },
                imageURL: nil,
                dateAdded: Date(),
                isAltered: isAltered
            )
            entries.append(entry)
        }

        return ImportResult(entries: entries, skippedRows: skipped, errors: errors)
    }

    // MARK: - File Operations

    func saveToFile(_ entries: [CollectionEntry]) -> URL? {
        let csv = export(entries)
        let filename = "mtg_collection_\(datestamp()).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("[CSVService] Write error: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }

    private func datestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: Date())
    }
}

// MARK: - CardCondition Moxfield parsing

private extension CardCondition {
    static func fromMoxfield(_ code: String) -> CardCondition {
        switch code.trimmingCharacters(in: .whitespaces).uppercased() {
        case "MI": return .mint
        case "NM": return .nearMint
        case "LP": return .lightlyPlayed
        case "GO": return .good
        case "PO": return .poor
        default:   return .nearMint
        }
    }
}

// MARK: - CollectionEntry memberwise init (for CSV import)

extension CollectionEntry {
    init(id: UUID, count: Int, cardID: String, name: String, setCode: String, setName: String,
         collectorNumber: String, rarity: String, condition: CardCondition, isFoil: Bool,
         language: String, purchasePrice: Double?, usdPrice: String?, imageURL: URL?, dateAdded: Date, isAltered: Bool) {
        self.id              = id
        self.count           = count
        self.cardID          = cardID
        self.name            = name
        self.setCode         = setCode
        self.setName         = setName
        self.collectorNumber = collectorNumber
        self.rarity          = rarity
        self.condition       = condition
        self.isFoil          = isFoil
        self.language        = language
        self.purchasePrice   = purchasePrice
        self.usdPrice        = usdPrice
        self.imageURL        = imageURL
        self.dateAdded       = dateAdded
        self.isAltered       = isAltered
    }
}
