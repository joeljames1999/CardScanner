//
//  FeaturePrintIndexer.swift
//  TcgScanner
//
//  Created by Joel James on 17/06/2026.
//

import Foundation
import UIKit
import Vision
import SQLite3

final class FeaturePrintIndexer {

    static let shared = FeaturePrintIndexer()

    private init() {}

    func buildDatabase() async {

        let cards =
            CardDatabaseService.shared.allCards()

        for (index, card) in cards.enumerated() {

            guard
                let url =
                    card.imageUris?.artCrop
                    ?? card.imageUris?.normal
            else {
                continue
            }

            do {

                let (data, _) =
                    try await URLSession.shared
                        .data(from: url)

                guard let image =
                    UIImage(data: data)
                else {
                    continue
                }

                guard let observation =
                    await VisionFeaturePrintService.shared
                        .generateFeaturePrint(
                            from: image
                        )
                else {
                    continue
                }

                let archived =
                    try CardDatabaseService.shared
                        .generateFeaturePrint(
                            from: observation
                        )

                CardDatabaseService.shared
                    .storeFeaturePrint(
                        cardId: card.id,
                        data: archived
                    )

                if index % 100 == 0 {

                    print(
                        "[Vision] Indexed",
                        index,
                        "/",
                        cards.count
                    )
                }

            } catch {

                print(error)
            }
        }
    }
}
