import XCTest
@testable import TcgScanner

final class SearchFilterTests: XCTestCase {

    func testManaCostBucketCapsValuesAboveSix() {
        XCTAssertEqual(SearchFilter.manaCostBucket(for: nil), 0)
        XCTAssertEqual(SearchFilter.manaCostBucket(for: 3.5), 3)
        XCTAssertEqual(SearchFilter.manaCostBucket(for: 7), 6)
    }

    func testExtractManaColorsIgnoresUnknownCodes() {
        let colors = SearchFilter.extractManaColors(from: ["R", "U", "X"])

        XCTAssertEqual(colors, [.red, .blue])
    }

    func testIncludesOnlyTheseRequiresExactColorMatch() {
        XCTAssertTrue(SearchFilter.cardColorsMatch(
            [.red, .green],
            selectedColors: [.red, .green],
            mode: .includesOnlyThese
        ))

        XCTAssertFalse(SearchFilter.cardColorsMatch(
            [.red, .green, .blue],
            selectedColors: [.red, .green],
            mode: .includesOnlyThese
        ))
    }

    func testIncludesAnyOfTheseMatchesAnySelectedColor() {
        XCTAssertTrue(SearchFilter.cardColorsMatch(
            [.red, .green],
            selectedColors: [.blue, .green],
            mode: .includesAnyOfThese
        ))

        XCTAssertFalse(SearchFilter.cardColorsMatch(
            [.red],
            selectedColors: [.blue, .green],
            mode: .includesAnyOfThese
        ))
    }

    func testColorlessSelectionMatchesOnlyColorlessCards() {
        XCTAssertTrue(SearchFilter.cardColorsMatch(
            [],
            selectedColors: [.colorless],
            mode: .includesOnlyThese
        ))

        XCTAssertTrue(SearchFilter.cardColorsMatch(
            [],
            selectedColors: [.colorless],
            mode: .includesAnyOfThese
        ))

        XCTAssertFalse(SearchFilter.cardColorsMatch(
            [.red],
            selectedColors: [.colorless],
            mode: .includesAnyOfThese
        ))
    }

    func testResetClearsActiveFilterState() {
        var filter = SearchFilter()
        filter.selectedRarities = ["rare"]
        filter.selectedManaCosts = [3]
        filter.selectedManaColors = [.red]
        filter.selectedFormats = [.commander]

        XCTAssertTrue(filter.hasActiveFilters)

        filter.reset()

        XCTAssertFalse(filter.hasActiveFilters)
        XCTAssertEqual(filter.colorFilterMode, .includesAnyOfThese)
    }
}
