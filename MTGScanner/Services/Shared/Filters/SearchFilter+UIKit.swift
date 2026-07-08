//
//  SearchFilter+UIKit.swift
//  TcgScanner
//

import UIKit

extension SearchFilter.ManaColor {

    var color: UIColor {
        switch self {
        case .white:
            return UIColor(red: 0.95, green: 0.95, blue: 0.90, alpha: 1)
        case .blue:
            return UIColor(red: 0.2, green: 0.6, blue: 0.95, alpha: 1)
        case .black:
            return UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        case .red:
            return UIColor(red: 0.95, green: 0.3, blue: 0.2, alpha: 1)
        case .green:
            return UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1)
        case .colorless:
            return UIColor(red: 211 / 255, green: 211 / 255, blue: 211 / 255, alpha: 1)
        }
    }

    var image: UIImage? {
        switch self {
        case .white:
            return UIImage.whiteManaSymbol
        case .blue:
            return UIImage.blueManaSymbol
        case .black:
            return UIImage.blackManaSymbol
        case .red:
            return UIImage.redManaSymbol
        case .green:
            return UIImage.greenManaSymbol
        case .colorless:
            return UIImage.colourlessManaSymbol
        }
    }
}
