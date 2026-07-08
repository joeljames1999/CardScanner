import XCTest
@testable import TcgScanner

final class CSVHeaderMapperTests: XCTestCase {

    func testGenericFormatDetectsCommonAliases() {
        let format = CSVFormat.detect(headers: [
            "Quantity",
            "Card Name",
            "Set Code",
            "Collector_Number"
        ])

        XCTAssertEqual(format, .generic)
    }

    func testDetectRecognizesKnownExportFormats() {
        XCTAssertEqual(CSVFormat.detect(headers: ["Name", "Tradelist Count", "Last Modified"]), .moxfield)
        XCTAssertEqual(CSVFormat.detect(headers: ["Name", "ManaBox ID"]), .manabox)
        XCTAssertEqual(CSVFormat.detect(headers: ["Name", "Categories"]), .archidekt)
        XCTAssertEqual(CSVFormat.detect(headers: ["Name", "Inventory ID"]), .deckbox)
        XCTAssertEqual(CSVFormat.detect(headers: ["Name", "Folder"]), .dragonShield)
    }

    func testMapperFindsNormalizedGenericHeaders() {
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

        XCTAssertEqual(mapper.quantity, 0)
        XCTAssertEqual(mapper.name, 1)
        XCTAssertEqual(mapper.setCode, 2)
        XCTAssertEqual(mapper.collectorNumber, 3)
        XCTAssertEqual(mapper.foil, 4)
    }

    func testValueTrimsWhitespaceAndReturnsEmptyForMissingIndex() {
        let mapper = CSVHeaderMapper(headers: ["Name"], format: .generic)

        XCTAssertEqual(mapper.value(at: 0, from: [" Lightning Bolt "]), "Lightning Bolt")
        XCTAssertEqual(mapper.value(at: 1, from: ["Lightning Bolt"]), "")
        XCTAssertEqual(mapper.value(at: nil, from: ["Lightning Bolt"]), "")
    }
}
