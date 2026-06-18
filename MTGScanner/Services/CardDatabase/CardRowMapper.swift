//
//  CardRowMapper.swift
//  TcgScanner
//
//  Created by Joel James on 17/06/2026.
//

import Foundation
import SQLite3
    
enum CardRowMapper {
    
    private static func col(
        _ stmt: OpaquePointer?,
        _ index: Int32
    ) -> String? {
        
        guard let stmt else {
            return nil
        }
        
        let count = sqlite3_column_count(stmt)
        
        guard index >= 0, index < count else {
            return nil
        }
        
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else {
            return nil
        }
        
        guard let ptr = sqlite3_column_text(stmt, index) else {
            return nil
        }
        
        return String(cString: ptr)
    }
    
    static func map(
        _ stmt: OpaquePointer?
    ) -> MTGCard? {
        
        guard let stmt else {
            print("[CardDB] stmt nil")
            return nil
        }
        
        guard
            let name = col(stmt, CardColumn.name)
        else {
            return nil
        }
        
        let imageUris: MTGCard.ImageUris? = {
            
            let normalURL =
            col(stmt, CardColumn.imageUriNormal)
            
            let artCropURL =
            col(stmt, CardColumn.imageUriArtCrop)
            
            return MTGCard.ImageUris(
                small: nil,
                normal: normalURL.flatMap(URL.init),
                large: nil,
                artCrop: artCropURL.flatMap(URL.init)
            )
        }()
        
        let prices: MTGCard.Prices? = {
            
            let usd = col(
                stmt,
                CardColumn.priceUsd
            )
            
            let foil = col(
                stmt,
                CardColumn.priceUsdFoil
            )
            
            guard usd != nil || foil != nil else {
                return nil
            }
            
            return MTGCard.Prices(
                usd: usd,
                usdFoil: foil,
                eur: nil
            )
        }()
        
        let colors = col(
            stmt,
            CardColumn.colors
        )?
            .split(separator: ",")
            .map(String.init)
        
        let colorIdentity = col(
            stmt,
            CardColumn.colorIdentity
        )?
            .split(separator: ",")
            .map(String.init)
        
        let legalitiesJSONString = col(
            stmt,
            CardColumn.legalities
        )
        
        var legalities: Legalities?
        
        if let legalitiesJSONString,
           let data = legalitiesJSONString.data(using: .utf8) {
            
            legalities = try? JSONDecoder().decode(
                Legalities.self,
                from: data
            )
        }
        
        return MTGCard(
            id: col(
                stmt,
                CardColumn.cardID
            ) ?? UUID().uuidString,
            
            name: name,
            
            manaCost: col(
                stmt,
                CardColumn.manaCost
            ),
            
            cmc: sqlite3_column_double(
                stmt,
                CardColumn.cmc
            ),
            
            colors: colors,
            
            colorIdentity: colorIdentity,
            
            artist: col(
                stmt,
                CardColumn.artist
            ),
            
            typeLine: col(
                stmt,
                CardColumn.typeLine
            ) ?? "",
            
            oracleText: col(
                stmt,
                CardColumn.oracleText
            ),
            
            power: col(
                stmt,
                CardColumn.power
            ),
            
            toughness: col(
                stmt,
                CardColumn.toughness
            ),
            
            rarity: col(
                stmt,
                CardColumn.rarity
            ) ?? "common",
            
            set: col(
                stmt,
                CardColumn.setCode
            ) ?? "",
            
            setName: col(
                stmt,
                CardColumn.setName
            ) ?? "",
            
            collectorNumber: col(
                stmt,
                CardColumn.collectorNumber
            ) ?? "",
            
            imageUris: imageUris,
            
            prices: prices,
            
            scryfallUri: col(
                stmt,
                CardColumn.scryfallUri
            ).flatMap(URL.init(string:)),
            
            cardLayout: col(stmt, CardColumn.cardLayout),
            
            setType: col(stmt, CardColumn.setType), legalities: legalities
        )
    }
}
