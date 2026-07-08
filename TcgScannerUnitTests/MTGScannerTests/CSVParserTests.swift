import XCTest
@testable import TcgScanner

final class CSVParserTests: XCTestCase {

    func testParseLineSplitsBasicCommaSeparatedValues() {
        let fields = CSVParser.parseLine("Count,Name,Edition")

        XCTAssertEqual(fields, ["Count", "Name", "Edition"])
    }

    func testParseLineKeepsCommasInsideQuotedFields() {
        let fields = CSVParser.parseLine("1,\"Atraxa, Grand Unifier\",ONE")

        XCTAssertEqual(fields, ["1", "Atraxa, Grand Unifier", "ONE"])
    }

    func testParseLineUnescapesDoubleQuotesInsideQuotedFields() {
        let fields = CSVParser.parseLine("1,\"The \"\"Great\"\" Henge\",ELD")

        XCTAssertEqual(fields, ["1", "The \"Great\" Henge", "ELD"])
    }

    func testParseSplitsMultipleRows() {
        let rows = CSVParser.parse("""
        Count,Name
        2,Lightning Bolt
        1,Sol Ring
        """)

        XCTAssertEqual(rows, [
            ["Count", "Name"],
            ["2", "Lightning Bolt"],
            ["1", "Sol Ring"]
        ])
    }
}
