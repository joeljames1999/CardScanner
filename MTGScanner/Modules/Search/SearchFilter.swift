import Foundation
import UIKit

// MARK: - Color Filter Mode

enum ColorFilterMode: String, CaseIterable {
    case includesOnlyThese = "Includes Only These Colors"
    case includesAnyOfThese = "Includes Any of These Colors"
}


//MARK: - Format filter
enum FormatFilter: String, CaseIterable, Codable {

    case standard
    case pioneer
    case modern
    case legacy
    case vintage
    case commander
    case pauper
    case brawl
    case historic
    case timeless
    case explorer

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - SearchFilter

struct SearchFilter: Equatable {
    
    // MARK: - Filter Options
    
    var selectedRarities: Set<String> = []
    var selectedSets: Set<String> = []
    var selectedManaCosts: Set<Int> = []
    var selectedManaColors: Set<ManaColor> = []
    var selectedArtists: Set<String> = []
    var colorFilterMode: ColorFilterMode = .includesAnyOfThese
    var selectedFormats: Set<FormatFilter> = []
    
    var legalCardsOnly = true
     var groupPrintings = true
    
    // MARK: - Mana Colors
    
    enum ManaColor: String, CaseIterable, Codable, Hashable {
        case white = "W"
        case blue = "U"
        case black = "B"
        case red = "R"
        case green = "G"
        case colorless = ""
        
        var displayName: String {
            switch self {
            case .white: return "White"
            case .blue: return "Blue"
            case .black: return "Black"
            case .red: return "Red"
            case .green: return "Green"
            case .colorless: return "Colorless"
            }
        }
        
        var symbol: String {
            switch self {
            case .white: return "⚪"
            case .blue: return "🔵"
            case .black: return "⚫"
            case .red: return "🔴"
            case .green: return "🟢"
            case .colorless: return "🔘"
            }
        }
        
        var color: UIColor {
            switch self {
            case .white: return UIColor(red: 0.95, green: 0.95, blue: 0.90, alpha: 1)
            case .blue: return UIColor(red: 0.2, green: 0.6, blue: 0.95, alpha: 1)
            case .black: return UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
            case .red: return UIColor(red: 0.95, green: 0.3, blue: 0.2, alpha: 1)
            case .green: return UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1)
            case .colorless: return UIColor(red: 211/255, green: 211/255, blue: 211/255, alpha: 1)
            }
        }
        
        var image: UIImage? {
            switch self {
            case .white: return UIImage.whiteManaSymbol
            case .blue: return UIImage.blueManaSymbol
            case .black: return UIImage.blackManaSymbol
            case .red: return UIImage.redManaSymbol
            case .green: return UIImage.greenManaSymbol
            case .colorless: return UIImage.colourlessManaSymbol
            }
        }
    }
    
    // MARK: - Utilities
    
    var hasActiveFilters: Bool {
        !selectedRarities.isEmpty ||
        !selectedSets.isEmpty ||
        !selectedManaCosts.isEmpty ||
        !selectedManaColors.isEmpty ||
        !selectedArtists.isEmpty ||
        !selectedFormats.isEmpty
    }
    
    mutating func reset() {
        selectedRarities.removeAll()
        selectedSets.removeAll()
        selectedManaCosts.removeAll()
        selectedManaColors.removeAll()
        selectedArtists.removeAll()
        colorFilterMode = .includesAnyOfThese
        selectedFormats.removeAll()
    }
}

// MARK: - Color Matching Logic

extension SearchFilter {
    
    /// Determines the mana cost bucket (0-5, or 6+)
    static func manaCostBucket(for cmc: Double?) -> Int {
        guard let cmc = cmc else { return 0 }
        let bucket = Int(cmc)
        return bucket > 6 ? 6 : bucket
    }
    
    /// Convert color string codes to ManaColor enum
    /// Expects strings like ["R", "U", "B", "G", "W"]
    static func extractManaColors(from colorArray: [String]?) -> Set<ManaColor> {
        guard let colors = colorArray, !colors.isEmpty else { return [] }
        
        var result: Set<ManaColor> = []
        for colorCode in colors {
            if let manaColor = ManaColor(rawValue: colorCode) {
                result.insert(manaColor)
            }
        }
        return result
    }
    
    static func cardColorsMatch(
        _ cardColors: Set<ManaColor>,
        selectedColors: Set<ManaColor>,
        mode: ColorFilterMode
    ) -> Bool {

        guard !selectedColors.isEmpty else {
            return true
        }

        switch mode {

        case .includesOnlyThese:

            let wantsColorless =
                selectedColors.contains(.colorless)

            let selectedNonColorless =
                selectedColors.subtracting([.colorless])

            if wantsColorless {

                if selectedNonColorless.isEmpty {
                    return cardColors.isEmpty
                }

                return false
            }

            return cardColors == selectedNonColorless

        case .includesAnyOfThese:

            let wantsColorless =
                selectedColors.contains(.colorless)

            let selectedNonColorless =
                selectedColors.subtracting([.colorless])

            let matchesColorless =
                wantsColorless &&
                cardColors.isEmpty

            let matchesColours =
                !selectedNonColorless.isEmpty &&
                !cardColors.isDisjoint(
                    with: selectedNonColorless
                )

            return matchesColorless || matchesColours
        }
    }
}

extension Legalities {

    func isLegal(in format: FormatFilter) -> Bool {

        switch format {

        case .standard:
            return standard == "legal"

        case .pioneer:
            return pioneer == "legal"

        case .modern:
            return modern == "legal"

        case .legacy:
            return legacy == "legal"

        case .vintage:
            return vintage == "legal" || vintage == "restricted"

        case .commander:
            return commander == "legal"

        case .pauper:
            return pauper == "legal"

        case .brawl:
            return brawl == "legal"

        case .historic:
            return historic == "legal"

        case .timeless:
            return timeless == "legal"

        case .explorer:
            return explorer == "legal"
        }
    }
}
