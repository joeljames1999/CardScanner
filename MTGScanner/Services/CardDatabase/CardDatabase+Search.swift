//
//  CardDatabase+Search.swift
//  TcgScanner
//
//  Created by Joel James on 17/06/2026.
//

import Foundation
import SQLite3

extension CardDatabaseService {
    
    func searchCards(
        query: String,
        filter: SearchFilter
    ) -> [MTGCard] {
        
        databaseQueue.sync {
            
            print("========== SEARCH ==========")
            print("Query: \(query)")
            print("Selected colours: \(filter.selectedManaColors)")
            print("Selected rarities: \(filter.selectedRarities)")
            print("Selected sets: \(filter.selectedSets)")
            print("Selected mana costs: \(filter.selectedManaCosts)")
            print("============================")
            
            let trimmed = query.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            
            guard !trimmed.isEmpty || filter.hasActiveFilters else {
                return []
            }
            
            var whereClauses: [String] = []
            var params: [String] = []
            
            // Text search
            if !trimmed.isEmpty {
                
                let cleaned = trimmed
                    .replacingOccurrences(of: "0", with: "O")
                    .replacingOccurrences(of: "1", with: "I")
                    .replacingOccurrences(of: "|", with: "I")
                
                whereClauses.append(
                    "name LIKE ? COLLATE NOCASE"
                )
                
                params.append("%\(cleaned)%")
            }
            
            // Rarity filter
            if !filter.selectedRarities.isEmpty {
                
                let rarities = filter.selectedRarities
                    .map { "'\($0)'" }
                    .joined(separator: ",")
                
                whereClauses.append(
                    "rarity IN (\(rarities))"
                )
            }
            
            // Set filter
            if !filter.selectedSets.isEmpty {
                
                let sets = filter.selectedSets
                    .map { "'\($0)'" }
                    .joined(separator: ",")
                
                whereClauses.append(
                    "set_name IN (\(sets))"
                )
            }
            
            // Mana cost filter
            if !filter.selectedManaCosts.isEmpty {
                
                let costs = filter.selectedManaCosts
                    .map { cost in
                        
                        if cost == 6 {
                            return "cmc >= 6"
                        }
                        
                        return "cmc = \(cost)"
                    }
                    .joined(separator: " OR ")
                
                whereClauses.append(
                    "(\(costs))"
                )
            }
            
            var sql = """
            SELECT *
            FROM cards
            """
            
            if !whereClauses.isEmpty {
                sql += " WHERE "
                sql += whereClauses.joined(separator: " AND ")
            }
            
            sql += " ORDER BY name ASC;"
            
            print("SQL:")
            print(sql)
            
            print("Params:")
            print(params)
            
            var results = executeFilteredQuery(
                sql,
                params: params
            )
            
            print("SQL Results Before Colour Filter: \(results.count)")
            
            if filter.legalCardsOnly {
                
                results = results.filter { card in
                    
                    let layout = card.cardLayout?.lowercased() ?? ""
                    let typeLine = card.typeLine.lowercased()
                    let setName = card.setName.lowercased()
                    
                    if [
                        "token",
                        "emblem",
                        "art_series",
                        "planar",
                        "scheme",
                        "vanguard",
                        "double_faced_token",
                        "playtest"
                    ].contains(layout) {
                        return false
                    }
                    
                    if typeLine.contains("token") {
                        return false
                    }
                    
                    if setName.contains("tokens") {
                        return false
                    }
                    
                    if setName.contains("playtest") {
                        return false
                    }
                    if !(card.legalities?.isLegalSomewhere ?? false) {
                        return false
                    }
                    
                    return true
                }
            }
            
            if !filter.selectedManaColors.isEmpty {
                
                results = results.filter { card in
                    
                    let cardColors = SearchFilter.extractManaColors(
                        from: card.colors
                    )
                    
                    return SearchFilter.cardColorsMatch(
                        cardColors,
                        selectedColors: filter.selectedManaColors,
                        mode: filter.colorFilterMode
                    )
                }
                
                print(
                    "Results After Colour Filter:",
                    results.count
                )
            }
            
            if !filter.selectedFormats.isEmpty {
                
                results = results.filter { card in
                    
                    guard let legalities = card.legalities else {
                        return false
                    }
                    
                    return filter.selectedFormats.contains { format in
                        legalities.isLegal(in: format)
                    }
                }
                
                print(
                    "Results After Format Filter:",
                    results.count
                )
            }
            
            if filter.groupPrintings {
                
                var uniqueCards: [MTGCard] = []
                var seenNames = Set<String>()
                
                for card in results {
                    
                    let key = card.name.lowercased()
                    
                    guard !seenNames.contains(key) else {
                        continue
                    }
                    
                    seenNames.insert(key)
                    uniqueCards.append(card)
                }
                
                return uniqueCards
            }
            
            return results
        }
    }
    
    /// Internal helper to execute filtered queries (already inside databaseQueue.sync)
    private func executeFilteredQuery(_ sql: String, params: [String]) -> [MTGCard] {
        var stmt: OpaquePointer?
        
        guard sqlite3_prepare_v2(
            db,
            sql,
            -1,
            &stmt,
            nil
        ) == SQLITE_OK else {
            print("[CardDB] Filter prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        
        defer { sqlite3_finalize(stmt) }
        
        // Bind parameters
        for (index, param) in params.enumerated() {
            sqlite3_bind_text(
                stmt,
                Int32(index + 1),
                param,
                -1,
                unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            )
        }
        
        var results: [MTGCard] = []
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let card = CardRowMapper.map(stmt) {
                results.append(card)
            }
        }
        
        return results
    }
    
    /// Get all available sets (THREAD-SAFE)
    func getAllSets() -> [String] {
        databaseQueue.sync {
            let sql = """
                SELECT DISTINCT set_name
                FROM cards
                ORDER BY set_name ASC;
                """
            
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                print("[CardDB] getAllSets prepare failed: \(String(cString: sqlite3_errmsg(db)))")
                return []
            }
            
            defer { sqlite3_finalize(stmt) }
            
            var sets: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let setName = col(stmt, 0) {
                    sets.append(setName)
                }
            }
            
            print("[CardDB] Loaded \(sets.count) unique sets")
            return sets
        }
    }
    
    /// Get all available rarities (THREAD-SAFE)
    func getAllRarities() -> [String] {
        databaseQueue.sync {
            let sql = """
                SELECT DISTINCT rarity
                FROM cards
                WHERE rarity IS NOT NULL AND rarity != ''
                ORDER BY rarity ASC;
                """
            
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                print("[CardDB] getAllRarities prepare failed: \(String(cString: sqlite3_errmsg(db)))")
                return []
            }
            
            defer { sqlite3_finalize(stmt) }
            
            var rarities: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let rarity = col(stmt, 0) {
                    rarities.append(rarity)
                }
            }
            
            return rarities
        }
    }
    func cards(
        withIllustrationID illustrationID: String
    ) -> [MTGCard] {
        
        let sql = """
        SELECT *
        FROM cards
        WHERE illustration_id = ?
        ORDER BY rowid DESC
        """
        
        let SQLITE_TRANSIENT = unsafeBitCast(
            -1,
            to: sqlite3_destructor_type.self
        )
        
        var stmt: OpaquePointer?
        
        guard sqlite3_prepare_v2(
            db,
            sql,
            -1,
            &stmt,
            nil
        ) == SQLITE_OK else {
            return []
        }
        
        defer {
            sqlite3_finalize(stmt)
        }
        
        sqlite3_bind_text(
            stmt,
            1,
            illustrationID,
            -1,
            SQLITE_TRANSIENT
        )
        
        var cards: [MTGCard] = []
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            
            if let card =
                CardRowMapper.map(stmt) {
                
                cards.append(card)
            }
        }
        
        return cards
    }
    
    func cardsGroupedByIllustration(
        _ cards: [MTGCard]
    ) -> [MTGCard] {

        var groups: [String: MTGCard] = [:]
        var result: [MTGCard] = []

        for card in cards {

            guard let illustrationID =
                card.illustrationID
            else {

                result.append(card)
                continue
            }

            if groups[illustrationID] == nil {
                groups[illustrationID] = card
            }
        }

        result.append(
            contentsOf: groups.values
        )

        return result
    }
}
