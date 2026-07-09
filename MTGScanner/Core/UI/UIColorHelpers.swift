//
//  UIColorHelpers.swift
//  TcgScanner
//
//  Created by Joel James on 25/06/2026.
//

import Foundation
import UIKit

extension UIColor {
    
    static let brandBlue = UIColor(
        red: 0.16,
        green: 0.58,
        blue: 1.0,
        alpha: 1.0
    )
    
    static let accentColor = UIColor(
        red: 85 / 255,
        green: 189 / 255,
        blue: 251 / 255,
        alpha: 1
    )

    static let brandBlueDark = UIColor(
        red: 0.08,
        green: 0.34,
        blue: 0.72,
        alpha: 1.0
    )

    static let brandBlueSoft = UIColor(
        red: 0.16,
        green: 0.58,
        blue: 1.0,
        alpha: 0.14
    )
    
    static let commonColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
    static let uncommonColor = UIColor(red: 0.741, green: 0.827, blue: 0.89, alpha: 1) // #bdd3e3
    static let rareColor = UIColor(red: 0.722, green: 0.639, blue: 0.459, alpha: 1) // #b8a375
    static let mythicColor = UIColor(red: 1, green: 0.478, blue: 0.055, alpha: 1) // #ff7a0e
    
    
    static func rarityColor(_ rarity: String) -> UIColor {

        switch rarity.lowercased() {

        case "common":
            return .commonColor
        case "uncommon":
            return .uncommonColor
        case "rare":
            return .rareColor
        case "mythic":
            return .mythicColor
        default:
            return .label
        }
    }
}
