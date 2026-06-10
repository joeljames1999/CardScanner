import Foundation
import UIKit

// MARK: - Color Filter Mode

enum ColorFilterMode: String, CaseIterable {
    case includesOnlyThese = "Includes Only These Colors"
    case includesAnyOfThese = "Includes Any of These Colors"
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
            case .colorless: return UIColor(red: 211, green: 211, blue: 211, alpha: 1)
            }
        }
    }
    
    // MARK: - Utilities
    
    var hasActiveFilters: Bool {
        !selectedRarities.isEmpty ||
        !selectedSets.isEmpty ||
        !selectedManaCosts.isEmpty ||
        !selectedManaColors.isEmpty ||
        !selectedArtists.isEmpty
    }
    
    mutating func reset() {
        selectedRarities.removeAll()
        selectedSets.removeAll()
        selectedManaCosts.removeAll()
        selectedManaColors.removeAll()
        selectedArtists.removeAll()
        colorFilterMode = .includesAnyOfThese
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
    
    /// Check if card colors match filter based on mode
    static func cardColorsMatch(
        _ cardColors: Set<ManaColor>,
        selectedColors: Set<ManaColor>,
        mode: ColorFilterMode
    ) -> Bool {
        guard !selectedColors.isEmpty else { return true }
        
        switch mode {
        case .includesOnlyThese:
            // Card must have EXACTLY the selected colors (no more, no less)
            return cardColors == selectedColors
            
        case .includesAnyOfThese:
            // Card must have AT LEAST ONE of the selected colors
            return !cardColors.intersection(selectedColors).isEmpty
        }
    }
}
