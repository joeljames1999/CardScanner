import Vision
import CoreImage
import UIKit

final class OCRService {

    var onRectangleDetected: ((VNRectangleObservation?) -> Void)?
    var onCardImageCaptured: ((UIImage) -> Void)?
    var onCardDetected: ((String) -> Void)?

    private let ciContext = CIContext()

    private var stableFrameCount = 0
    private let requiredStableFrames = 5
    private var lastRect: VNRectangleObservation?
    private var isLocked = false

    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard !isLocked else { return }
        detectRectangle(in: pixelBuffer)
    }

    func resetCooldown() {
        stableFrameCount = 0
        lastRect = nil
        isLocked = false
    }

    private func detectRectangle(in pixelBuffer: CVPixelBuffer) {
        let request = VNDetectRectanglesRequest { [weak self] req, _ in
            guard let self else { return }

            guard let rect = (req.results as? [VNRectangleObservation])?.first else {
                DispatchQueue.main.async {
                    self.onRectangleDetected?(nil)
                }
                return
            }

            let aspect = rect.boundingBox.width / rect.boundingBox.height
            guard aspect > 0.68 && aspect < 0.75 else { return }

            if let last = lastRect,
               abs(last.boundingBox.origin.x - rect.boundingBox.origin.x) < 0.02,
               abs(last.boundingBox.origin.y - rect.boundingBox.origin.y) < 0.02 {
                stableFrameCount += 1
            } else {
                stableFrameCount = 0
            }

            lastRect = rect

            DispatchQueue.main.async {
                self.onRectangleDetected?(rect)
            }

            guard stableFrameCount >= requiredStableFrames else { return }

            captureCardImage(from: pixelBuffer, rectangle: rect)
        }

        request.maximumObservations = 1

        DispatchQueue.global(qos: .userInitiated).async {
            try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer).perform([request])
        }
    }

    private func captureCardImage(from pixelBuffer: CVPixelBuffer, rectangle: VNRectangleObservation) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        func toCI(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: point.x * ciImage.extent.width,
                y: point.y * ciImage.extent.height
            )
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: toCI(rectangle.topLeft)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: toCI(rectangle.topRight)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: toCI(rectangle.bottomRight)), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: toCI(rectangle.bottomLeft)), forKey: "inputBottomLeft")

        guard let corrected = filter.outputImage,
              let cgImage = ciContext.createCGImage(corrected, from: corrected.extent)
        else { return }

        isLocked = true

        DispatchQueue.main.async {
            self.onCardImageCaptured?(UIImage(cgImage: cgImage))
        }
    }
}
