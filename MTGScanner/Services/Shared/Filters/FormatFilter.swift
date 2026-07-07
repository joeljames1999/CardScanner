//
//  FormatFilter.swift
//  TcgScanner
//
//  Created by Joel James on 07/07/2026.
//

import Foundation

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

extension FormatFilter {

    func matches(
        _ legalities: Legalities
    ) -> Bool {

        switch self {

        case .standard:
            return legalities.standard == "legal"

        case .pioneer:
            return legalities.pioneer == "legal"

        case .modern:
            return legalities.modern == "legal"

        case .legacy:
            return legalities.legacy == "legal"

        case .vintage:
            return legalities.vintage == "legal"

        case .commander:
            return legalities.commander == "legal"

        case .pauper:
            return legalities.pauper == "legal"
        case .brawl:
            return legalities.brawl == "legal"
        case .historic:
            return legalities.historic == "legal"
        case .timeless:
            return legalities.timeless == "legal"
        case .explorer:
            return legalities.explorer == "legal"
        }
    }
}
