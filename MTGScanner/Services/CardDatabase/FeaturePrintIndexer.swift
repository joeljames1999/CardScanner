//
//  FeaturePrintIndexer.swift
//  TcgScanner
//
//  Created by Joel James on 17/06/2026.
//

import Foundation
import UIKit
import Vision

final class FeaturePrintIndexer {

    static let shared = FeaturePrintIndexer()

    private init() {}

    func buildDatabase() async {

        let cards = (try? AppDatabase.shared.cards.allCards()) ?? []

        print("[Vision] Starting feature print index for \(cards.count) cards")

        for (index, card) in cards.enumerated() {

            do {

                if try AppDatabase.shared.featurePrints.exists(cardID: card.id) {
                    continue
                }

                guard
                    let url = card.imageUris?.artCrop ?? card.imageUris?.normal
                else {
                    continue
                }

                let (data, _) = try await URLSession.shared.data(from: url)

                guard let image = UIImage(data: data) else {
                    continue
                }

                guard
                    let observation = await VisionFeaturePrintService.shared
                        .generateFeaturePrint(from: image)
                else {
                    continue
                }

                let archived = try archive(
                    observation
                )

                try AppDatabase.shared.featurePrints.save(
                    cardID: card.id,
                    featurePrint: archived,
                    croppedFeaturePrint: nil,
                    fullFeaturePrint: nil
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

                print(
                    "[Vision] Failed indexing \(card.name):",
                    error
                )
            }
        }

        print("[Vision] Finished feature print index")
    }
}

// MARK: - Archiving

private extension FeaturePrintIndexer {

    func archive(
        _ observation: VNFeaturePrintObservation
    ) throws -> Data {

        try NSKeyedArchiver.archivedData(
            withRootObject: observation,
            requiringSecureCoding: true
        )
    }
}
