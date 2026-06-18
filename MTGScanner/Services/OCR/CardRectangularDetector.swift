//
//  CardRectangularDetector.swift
//  TcgScanner
//
//  Created by Joel James on 17/06/2026.
//

import Foundation
import Vision
import CoreImage

final class CardRectangleDetector {

    private var stableFrameCount = 0
    private var lastRect: VNRectangleObservation?

    let requiredStableFrames = 4

    func reset() {
        stableFrameCount = 0
        lastRect = nil
    }

    func process(
        rects: [VNRectangleObservation]
    ) -> VNRectangleObservation? {

        let cardRects = rects.filter {
            isCardAspectRatio($0)
        }

        guard let rect = cardRects.max(
            by: {
                ($0.boundingBox.width * $0.boundingBox.height)
                <
                ($1.boundingBox.width * $1.boundingBox.height)
            }
        ) else {

            stableFrameCount =
                max(0, stableFrameCount - 1)

            return nil
        }

        if let last = lastRect {

            if isSameRect(rect, last) {
                stableFrameCount += 1
            } else {
                stableFrameCount =
                    max(0, stableFrameCount - 1)
            }

        } else {
            stableFrameCount = 1
        }

        lastRect = rect

        guard stableFrameCount >= requiredStableFrames else {
            return nil
        }

        stableFrameCount = 0
        return rect
    }

    private func isCardAspectRatio(
        _ rect: VNRectangleObservation
    ) -> Bool {

        let w = rect.boundingBox.width
        let h = rect.boundingBox.height

        guard w > 0, h > 0 else {
            return false
        }

        let aspect = w / h
        let inverse = h / w

        return
            (aspect > 0.55 && aspect < 0.85)
            ||
            (inverse > 0.55 && inverse < 0.85)
    }

    private func isSameRect(
        _ a: VNRectangleObservation,
        _ b: VNRectangleObservation
    ) -> Bool {

        let threshold: CGFloat = 0.08

        return
            abs(a.topLeft.x - b.topLeft.x) < threshold &&
            abs(a.topLeft.y - b.topLeft.y) < threshold &&
            abs(a.bottomRight.x - b.bottomRight.x) < threshold &&
            abs(a.bottomRight.y - b.bottomRight.y) < threshold
    }
}
