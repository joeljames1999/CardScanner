import Testing
@testable import TcgScanner

struct SearchFilterTests {

    @Test func manaCostBucketCapsValuesAboveSix() {
        #expect(SearchFilter.manaCostBucket(for: nil) == 0)
        #expect(SearchFilter.manaCostBucket(for: 3.5) == 3)
        #expect(SearchFilter.manaCostBucket(for: 7) == 6)
    }

    @Test func extractManaColorsIgnoresUnknownCodes() {
        let colors = SearchFilter.extractManaColors(from: ["R", "U", "X"])

        #expect(colors == [.red, .blue])
    }

    @Test func includesOnlyTheseRequiresExactColorMatch() {
        #expect(SearchFilter.cardColorsMatch(
            [.red, .green],
            selectedColors: [.red, .green],
            mode: .includesOnlyThese
        ))

        #expect(!SearchFilter.cardColorsMatch(
            [.red, .green, .blue],
            selectedColors: [.red, .green],
            mode: .includesOnlyThese
        ))
    }

    @Test func includesAnyOfTheseMatchesAnySelectedColor() {
        #expect(SearchFilter.cardColorsMatch(
            [.red, .green],
            selectedColors: [.blue, .green],
            mode: .includesAnyOfThese
        ))

        #expect(!SearchFilter.cardColorsMatch(
            [.red],
            selectedColors: [.blue, .green],
            mode: .includesAnyOfThese
        ))
    }

    @Test func colorlessSelectionMatchesOnlyColorlessCards() {
        #expect(SearchFilter.cardColorsMatch(
            [],
            selectedColors: [.colorless],
            mode: .includesOnlyThese
        ))

        #expect(SearchFilter.cardColorsMatch(
            [],
            selectedColors: [.colorless],
            mode: .includesAnyOfThese
        ))

        #expect(!SearchFilter.cardColorsMatch(
            [.red],
            selectedColors: [.colorless],
            mode: .includesAnyOfThese
        ))
    }

    @Test func resetClearsActiveFilterState() {
        var filter = SearchFilter()
        filter.selectedRarities = ["rare"]
        filter.selectedManaCosts = [3]
        filter.selectedManaColors = [.red]
        filter.selectedFormats = [.commander]

        #expect(filter.hasActiveFilters)

        filter.reset()

        #expect(!filter.hasActiveFilters)
        #expect(filter.colorFilterMode == .includesAnyOfThese)
    }
}
