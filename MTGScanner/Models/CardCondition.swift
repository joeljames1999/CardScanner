//
//  CardCondition.swift
//  TcgScanner
//
//  Created by Joel James on 19/06/2026.
//

import Foundation

enum CardCondition: String, Codable, CaseIterable {
    case mint = "Mint"
    case nearMint = "Near Mint"
    case good = "Good"
    case lightlyPlayed = "Lightly Played"
    case poor = "Poor"
    
    var moxfieldCode: String {
        switch self {
        case .mint:              return "MI"
        case .nearMint:         return "NM"
        case .lightlyPlayed:    return "LP"
        case .good:              return "GO"
        case .poor:              return "PO"
        }
    }
}
