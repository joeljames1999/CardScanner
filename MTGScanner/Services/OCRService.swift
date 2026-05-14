import Vision
import CoreImage
import UIKit

final class OCRService {

    var onRectangleDetected: ((VNRectangleObservation?) -> Void)?
    var onCardImageCaptured: ((UIImage) -> Void)?

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // Stability — card must be held steady for N frames before capture
    private var stableFrameCount = 0
    private let requiredStableFrames = 8
    private var lastRect: VNRectangleObservation?
    private var isLocked = false

    // Cache the working orientation once found
    private var workingOrientation: CGImagePropertyOrientation? = nil

    // MARK: - Public

    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard !isLocked else { return }
        detectCard(in: pixelBuffer)
    }

    func resetForNextScan() {
        isLocked = false
        stableFrameCount = 0
        lastRect = nil
    }

    func resetCooldown() {
        resetForNextScan()
    }

    // MARK: - Rectangle Detection

    private func detectCard(in pixelBuffer: CVPixelBuffer) {
        let request = VNDetectRectanglesRequest { [weak self] req, error in
            guard let self else { return }

            let allResults = req.results as? [VNRectangleObservation] ?? []

            if allResults.isEmpty {
                DispatchQueue.main.async { self.onRectangleDetected?(nil) }
                self.stableFrameCount = 0
                return
            }

            guard let rect = allResults.first(where: { self.isCardAspectRatio($0) }) else {
                print("[OCR] Rectangles found but none match card aspect ratio:")
                for r in allResults {
                    let aspect = r.boundingBox.width / r.boundingBox.height
                    print("[OCR]   aspect=\(String(format: "%.3f", aspect)) conf=\(String(format: "%.2f", r.confidence))")
                }
                DispatchQueue.main.async { self.onRectangleDetected?(nil) }
                self.stableFrameCount = 0
                return
            }

            print("[OCR] ✅ Card rect found — aspect=\(String(format: "%.3f", rect.boundingBox.width/rect.boundingBox.height)) stable=\(self.stableFrameCount)")

            DispatchQueue.main.async { self.onRectangleDetected?(rect) }

            if let last = self.lastRect, self.isSameRect(rect, last) {
                self.stableFrameCount += 1
            } else {
                self.stableFrameCount = 0
                self.lastRect = rect
            }

            guard self.stableFrameCount >= self.requiredStableFrames else { return }

            self.captureFullCard(from: pixelBuffer, rect: rect)
        }

        request.maximumObservations = 5
        request.minimumConfidence   = 0.5
        request.minimumAspectRatio  = 0.5
        request.maximumAspectRatio  = 0.9
        request.minimumSize         = 0.1
        request.quadratureTolerance = 45

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            // If we already know the working orientation, use it directly
            if let known = self.workingOrientation {
                let handler = VNImageRequestHandler(
                    cvPixelBuffer: pixelBuffer,
                    orientation: known,
                    options: [:]
                )
                try? handler.perform([request])
                return
            }

            // Otherwise try all orientations until one finds rectangles
            let orientations: [CGImagePropertyOrientation] = [.right, .up, .left, .down, .rightMirrored, .upMirrored]

            for orientation in orientations {
                // Reset results between attempts
                let probe = VNDetectRectanglesRequest()
                probe.maximumObservations = 3
                probe.minimumConfidence   = 0.4
                probe.minimumAspectRatio  = 0.4
                probe.maximumAspectRatio  = 1.0
                probe.minimumSize         = 0.05
                probe.quadratureTolerance = 45

                let handler = VNImageRequestHandler(
                    cvPixelBuffer: pixelBuffer,
                    orientation: orientation,
                    options: [:]
                )
                try? handler.perform([probe])

                let found = probe.results as? [VNRectangleObservation] ?? []
                if !found.isEmpty {
                    print("[OCR] 🎯 Working orientation found: \(orientation.debugName)")
                    self.workingOrientation = orientation
                    // Now run the real request with this orientation
                    let realHandler = VNImageRequestHandler(
                        cvPixelBuffer: pixelBuffer,
                        orientation: orientation,
                        options: [:]
                    )
                    try? realHandler.perform([request])
                    return
                }
            }

            print("[OCR] No rectangles found in any orientation")
        }
    }

    // MARK: - Card Capture + Perspective Correction

    private func captureFullCard(from pixelBuffer: CVPixelBuffer, rect: VNRectangleObservation) {
        guard !isLocked else { return }
        isLocked = true
        stableFrameCount = 0

        print("[OCR] 📸 Capturing card image…")

        let orientation = workingOrientation ?? .right
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Apply orientation so image is upright before perspective correction
        switch orientation {
        case .right:        ciImage = ciImage.oriented(.right)
        case .left:         ciImage = ciImage.oriented(.left)
        case .down:         ciImage = ciImage.oriented(.down)
        case .upMirrored:   ciImage = ciImage.oriented(.upMirrored)
        case .rightMirrored: ciImage = ciImage.oriented(.rightMirrored)
        default:            break // .up is already correct
        }

        guard let corrected = perspectiveCorrect(ciImage, rect: rect),
              let cgImage   = ciContext.createCGImage(corrected, from: corrected.extent)
        else {
            print("[OCR] ❌ Perspective correction failed")
            isLocked = false
            return
        }

        let cardImage = UIImage(cgImage: cgImage)
        print("[OCR] ✅ Card captured — size: \(cardImage.size)")

        DispatchQueue.main.async {
            self.onCardImageCaptured?(cardImage)
        }
    }

    private func perspectiveCorrect(_ image: CIImage, rect: VNRectangleObservation) -> CIImage? {
        let size = image.extent.size

        func toVector(_ point: CGPoint) -> CIVector {
            CIVector(x: point.x * size.width, y: point.y * size.height)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(image,                      forKey: kCIInputImageKey)
        filter.setValue(toVector(rect.topLeft),     forKey: "inputTopLeft")
        filter.setValue(toVector(rect.topRight),    forKey: "inputTopRight")
        filter.setValue(toVector(rect.bottomLeft),  forKey: "inputBottomLeft")
        filter.setValue(toVector(rect.bottomRight), forKey: "inputBottomRight")

        return filter.outputImage
    }

    // MARK: - Helpers

    private func isCardAspectRatio(_ rect: VNRectangleObservation) -> Bool {
        let w = rect.boundingBox.width
        let h = rect.boundingBox.height
        guard w > 0, h > 0 else { return false }

        let aspect = w / h
        let inverse = h / w

        // MTG card portrait = 0.716, landscape = 1.397
        // Accept either orientation
        let portraitMatch  = aspect  > 0.55 && aspect  < 0.85
        let landscapeMatch = inverse > 0.55 && inverse < 0.85

        return portraitMatch || landscapeMatch
    }

    private func isSameRect(_ a: VNRectangleObservation, _ b: VNRectangleObservation) -> Bool {
        let threshold: CGFloat = 0.04
        return abs(a.topLeft.x     - b.topLeft.x)     < threshold &&
               abs(a.topLeft.y     - b.topLeft.y)     < threshold &&
               abs(a.bottomRight.x - b.bottomRight.x) < threshold &&
               abs(a.bottomRight.y - b.bottomRight.y) < threshold
    }
}

// MARK: - Debug

private extension CGImagePropertyOrientation {
    var debugName: String {
        switch self {
        case .up:            return "up"
        case .down:          return "down"
        case .left:          return "left"
        case .right:         return "right"
        case .upMirrored:    return "upMirrored"
        case .downMirrored:  return "downMirrored"
        case .leftMirrored:  return "leftMirrored"
        case .rightMirrored: return "rightMirrored"
        default:             return "unknown"
        }
    }
}
