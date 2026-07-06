////
////  MTGCard+Display.swift
////  TcgScanner
////
////  Created by Joel James on 06/07/2026.
////
//
//import Foundation
//
//extension MTGCard {
//
//    var displayCard: DisplayCard {
//
//        if let faces = cardFaces,
//           !faces.isEmpty {
//
//            return DisplayCard(
//
//                id: id,
//
//                faces: faces.map {
//
//                    DisplayFace(
//
//                        name: $0.name,
//
//                        imageURL: $0.imageUris?.normal,
//
//                        manaCost: $0.manaCost,
//
//                        typeLine: $0.typeLine,
//
//                        oracleText: $0.oracleText,
//
//                        power: $0.power,
//
//                        toughness: $0.toughness
//                    )
//                },
//
//                rarity: rarity,
//
//                set: set,
//
//                setName: setName,
//
//                collectorNumber: collectorNumber,
//
//                prices: prices,
//
//                legalities: legalities
//            )
//        }
//
//        return DisplayCard(
//
//            id: id,
//
//            faces: [
//
//                DisplayFace(
//
//                    name: name,
//
//                    imageURL: imageUris?.normal,
//
//                    manaCost: manaCost,
//
//                    typeLine: typeLine,
//
//                    oracleText: oracleText,
//
//                    power: power,
//
//                    toughness: toughness
//                )
//            ],
//
//            rarity: rarity,
//
//            set: set,
//
//            setName: setName,
//
//            collectorNumber: collectorNumber,
//
//            prices: prices,
//
//            legalities: legalities
//        )
//    }
//}
