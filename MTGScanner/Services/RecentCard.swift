//
//  RecentCard.swift
//  TcgScanner
//
//  Created by Joel James on 20/06/2026.
//
import Foundation

struct RecentCard: Codable, Identifiable {

    let id: String
    let name: String
    let setName: String
    let imageURL: URL?

    init(card: MTGCard) {
        self.id = card.id
        self.name = card.name
        self.setName = card.setName
        self.imageURL = card.imageUris?.normal
    }
}
