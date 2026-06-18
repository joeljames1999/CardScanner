//
//  CardNameRecognizer.swift
//  TcgScanner
//
//  Created by Joel James on 17/06/2026.
//

import Foundation
import Vision
import UIKit

final class CardNameRecognizer {

    func recognise(
        from image: UIImage
    ) async -> String? {

        guard let cgImage = image.cgImage else {
            return nil
        }

        return await withCheckedContinuation {
            continuation in

            let request =
                VNRecognizeTextRequest {

                    request,
                    error in

                    guard error == nil else {

                        continuation.resume(
                            returning: nil
                        )

                        return
                    }

                    let strings =
                        (request.results
                            as? [VNRecognizedTextObservation])?
                        .compactMap {
                            $0.topCandidates(1)
                                .first?
                                .string
                        } ?? []

                    continuation.resume(
                        returning: strings.first?
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                    )
                }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            DispatchQueue.global(
                qos: .userInitiated
            ).async {

                let handler =
                    VNImageRequestHandler(
                        cgImage: cgImage,
                        options: [:]
                    )

                try? handler.perform(
                    [request]
                )
            }
        }
    }
}
