import XCTest
@testable import TcgScanner

final class CardConditionTests: XCTestCase {

    func testMoxfieldCodesMatchExpectedConditionCodes() {
        XCTAssertEqual(CardCondition.mint.moxfieldCode, "MI")
        XCTAssertEqual(CardCondition.nearMint.moxfieldCode, "NM")
        XCTAssertEqual(CardCondition.lightlyPlayed.moxfieldCode, "LP")
        XCTAssertEqual(CardCondition.good.moxfieldCode, "GO")
        XCTAssertEqual(CardCondition.poor.moxfieldCode, "PO")
    }
}
