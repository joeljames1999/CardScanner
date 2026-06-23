//
//  MTGCard+Legalities.swift
//  TcgScanner
//
//  Created by Joel James on 19/06/2026.
//

import Foundation

struct Legalities: Codable {
    
    let standard: String?
    let pioneer: String?
    let modern: String?
    let legacy: String?
    let vintage: String?
    let commander: String?
    let pauper: String?
    let brawl: String?
    let historic: String?
    let timeless: String?
    let explorer: String?
    let alchemy: String?

    var isLegalSomewhere: Bool {

        let formats: [String?] = [
            standard,
            pioneer,
            modern,
            legacy,
            vintage,
            commander,
            pauper,
            brawl,
            historic,
            timeless,
            explorer,
            alchemy
        ]

        for legality in formats {
            if legality == "legal" ||
                legality == "restricted" ||
                legality == "banned" {
                return true
            }
        }

        return false
    }
}
