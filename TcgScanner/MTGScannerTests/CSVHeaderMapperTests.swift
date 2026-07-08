import Testing
@testable import TcgScanner

struct CSVHeaderMapperTests {

    @Test func genericFormatDetectsCommonAliases() {
        let format = CSVFormat.detect(headers: [
            "Quantity",
            "Card Name",
            "Set Code",
            "Collector_Number"
        ])

        #expect(format == .generic)
    }

    @Test func detectRecognizesKnownExportFormats() {
        #expect(CSVFormat.detect(headers: ["Name", "Tradelist Count", "Last Modified"]) == .moxfield)
        #expect(CSVFormat.detect(headers: ["Name", "ManaBox ID"]) == .manabox)
        #expect(CSVFormat.detect(headers: ["Name", "Categories"]) == .archidekt)
        #expect(CSVFormat.detect(headers: ["Name", "Inventory ID"]) == .deckbox)
        #expect(CSVFormat.detect(headers: ["Name", "Folder"]) == .dragonShield)
    }

    @Test func mapperFindsNormalizedGenericHeaders() {
        let mapper = CSVHeaderMapper(
            headers: [
                " Quantity ",
                "Card Name",
                "SET CODE",
                "Collector_Number",
                "Finish"
            ],
            format: .generic
        )

        #expect(mapper.quantity == 0)
        #expect(mapper.name == 1)
        #expect(mapper.setCode == 2)
        #expect(mapper.collectorNumber == 3)
        #expect(mapper.foil == 4)
    }

    @Test func valueTrimsWhitespaceAndReturnsEmptyForMissingIndex() {
        let mapper = CSVHeaderMapper(headers: ["Name"], format: .generic)

        #expect(mapper.value(at: 0, from: [" Lightning Bolt "]) == "Lightning Bolt")
        #expect(mapper.value(at: 1, from: ["Lightning Bolt"]) == "")
        #expect(mapper.value(at: nil, from: ["Lightning Bolt"]) == "")
    }
}
