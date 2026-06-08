import Foundation
import UIKit

// MARK: - SearchFilter

struct SearchFilter: Equatable {
    
    // MARK: - Filter Options
    
    var selectedRarities: Set<String> = []
    var selectedSets: Set<String> = []
    var selectedManaCosts: Set<Int> = []
    var selectedManaColors: Set<ManaColor> = []
    var selectedArtists: Set<String> = []
    
    // MARK: - Mana Colors
    
    enum ManaColor: String, CaseIterable, Codable {
        case white = "W"
        case blue = "U"
        case black = "B"
        case red = "R"
        case green = "G"
        case colorless = "C"
        
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
        
        var color: UIColor {
            switch self {
            case .white: return UIColor(red: 0.95, green: 0.95, blue: 0.90, alpha: 1)
            case .blue: return UIColor(red: 0.2, green: 0.6, blue: 0.95, alpha: 1)
            case .black: return UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
            case .red: return UIColor(red: 0.95, green: 0.3, blue: 0.2, alpha: 1)
            case .green: return UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1)
            case .colorless: return UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
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
    }
}

// MARK: - Mana Cost Representation

extension SearchFilter {
    
    /// Determines the mana cost bucket (0-5, or 6+)
    static func manaCostBucket(for cmc: Double?) -> Int {
        guard let cmc = cmc else { return 0 }
        let bucket = Int(cmc)
        return bucket > 6 ? 6 : bucket
    }
    
    /// Parses mana colors from mana cost string (e.g., "{U}{B}{R}" -> [.blue, .black, .red])
    static func extractManaColors(from manaCost: String?) -> Set<ManaColor> {
        guard let manaCost = manaCost else { return [] }
        
        var colors: Set<ManaColor> = []
        for char in manaCost.uppercased() {
            switch char {
            case "W": colors.insert(.white)
            case "U": colors.insert(.blue)
            case "B": colors.insert(.black)
            case "R": colors.insert(.red)
            case "G": colors.insert(.green)
            case "C": colors.insert(.colorless)
            default: break
            }
        }
        return colors
    }
}
