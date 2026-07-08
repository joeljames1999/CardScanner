import Testing
@testable import TcgScanner

struct CSVParserTests {

    @Test func parseLineSplitsBasicCommaSeparatedValues() {
        let fields = CSVParser.parseLine("Count,Name,Edition")

        #expect(fields == ["Count", "Name", "Edition"])
    }

    @Test func parseLineKeepsCommasInsideQuotedFields() {
        let fields = CSVParser.parseLine("1,\"Atraxa, Grand Unifier\",ONE")

        #expect(fields == ["1", "Atraxa, Grand Unifier", "ONE"])
    }

    @Test func parseLineUnescapesDoubleQuotesInsideQuotedFields() {
        let fields = CSVParser.parseLine("1,\"The \"\"Great\"\" Henge\",ELD")

        #expect(fields == ["1", "The \"Great\" Henge", "ELD"])
    }

    @Test func parseSplitsMultipleRows() {
        let rows = CSVParser.parse("""
        Count,Name
        2,Lightning Bolt
        1,Sol Ring
        """)

        #expect(rows == [
            ["Count", "Name"],
            ["2", "Lightning Bolt"],
            ["1", "Sol Ring"]
        ])
    }
}
