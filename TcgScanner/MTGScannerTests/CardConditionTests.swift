import Testing
@testable import TcgScanner

struct CardConditionTests {

    @Test func moxfieldCodesMatchExpectedConditionCodes() {
        #expect(CardCondition.mint.moxfieldCode == "MI")
        #expect(CardCondition.nearMint.moxfieldCode == "NM")
        #expect(CardCondition.lightlyPlayed.moxfieldCode == "LP")
        #expect(CardCondition.good.moxfieldCode == "GO")
        #expect(CardCondition.poor.moxfieldCode == "PO")
    }
}
