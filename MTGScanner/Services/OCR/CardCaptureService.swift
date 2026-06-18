//
//  CardCaptureService.swift
//  TcgScanner
//
//  Created by Joel James on 17/06/2026.
//

import Foundation
import Vision
import CoreImage
import UIKit

final class CardCaptureService {

    private let ciContext =
        CIContext(
            options: [.useSoftwareRenderer: false]
        )

    func capture(
        from pixelBuffer: CVPixelBuffer,
        rect: VNRectangleObservation,
        orientation: CGImagePropertyOrientation
    ) -> UIImage? {

        var image =
            CIImage(cvPixelBuffer: pixelBuffer)

        switch orientation {

        case .right:
            image = image.oriented(.right)

        case .left:
            image = image.oriented(.left)

        case .down:
            image = image.oriented(.down)

        default:
            break
        }

        guard
            let corrected =
                perspectiveCorrect(
                    image,
                    rect: rect
                ),

            let cgImage =
                ciContext.createCGImage(
                    corrected,
                    from: corrected.extent
                )
        else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func perspectiveCorrect(
        _ image: CIImage,
        rect: VNRectangleObservation
    ) -> CIImage? {

        let size = image.extent.size

        func vector(
            _ point: CGPoint
        ) -> CIVector {

            CIVector(
                x: point.x * size.width,
                y: point.y * size.height
            )
        }

        guard
            let filter =
                CIFilter(
                    name: "CIPerspectiveCorrection"
                )
        else {
            return nil
        }

        filter.setValue(
            image,
            forKey: kCIInputImageKey
        )

        filter.setValue(
            vector(rect.topLeft),
            forKey: "inputTopLeft"
        )

        filter.setValue(
            vector(rect.topRight),
            forKey: "inputTopRight"
        )

        filter.setValue(
            vector(rect.bottomLeft),
            forKey: "inputBottomLeft"
        )

        filter.setValue(
            vector(rect.bottomRight),
            forKey: "inputBottomRight"
        )

        return filter.outputImage
    }
}
