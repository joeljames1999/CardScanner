//
//  UIImageHelpers.swift
//  TcgScanner
//
//  Created by Joel James on 23/06/2026.
//

import Foundation
import UIKit

extension UIImage {

    func artworkCrop() -> UIImage? {

        guard let cgImage else {
            return nil
        }

        let rect = CGRect(
            x: size.width * 0.07,
            y: size.height * 0.12,
            width: size.width * 0.86,
            height: size.height * 0.32
        )

        let scale = self.scale

        let cropRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )

        guard let cropped =
            cgImage.cropping(to: cropRect)
        else {
            return nil
        }

        return UIImage(
            cgImage: cropped,
            scale: scale,
            orientation: imageOrientation
        )
    }
    
    func normalizedLandscape() -> UIImage {
        if size.width > size.height {
            return self
        }

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(
                width: size.height,
                height: size.width
            )
        )

        return renderer.image { context in
            context.cgContext.translateBy(
                x: size.height / 2,
                y: size.width / 2
            )
            context.cgContext.rotate(
                by: -.pi / 2
            )
            draw(
                in: CGRect(
                    x: -size.width / 2,
                    y: -size.height / 2,
                    width: size.width,
                    height: size.height
                )
            )
        }
    }
}
