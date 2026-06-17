import Vision
import CoreImage
import UIKit

final class OCRService {

    var onRectangleDetected: ((VNRectangleObservation?) -> Void)?
    var onCardImageCaptured: ((UIImage) -> Void)?

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // Stability — card must be held steady for N frames before capture
    private var stableFrameCount = 0
    private let requiredStableFrames = 4
    private var lastRect: VNRectangleObservation?
    private var isLocked = false
    private(set) var recognisedCardName: String?

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
        recognisedCardName = nil
    }

    func resetCooldown() {
        resetForNextScan()
    }

    // MARK: - Rectangle Detection

    private func detectCard(in pixelBuffer: CVPixelBuffer) {

        let request = VNDetectRectanglesRequest { [weak self] req, error in
            guard let self else { return }

            let allRects =
                req.results as? [VNRectangleObservation] ?? []

            if allRects.isEmpty {

                DispatchQueue.main.async {
                    self.onRectangleDetected?(nil)
                }

                self.stableFrameCount = max(
                    0,
                    self.stableFrameCount - 1
                )

                return
            }

            let cardRects =
                allRects.filter {
                    self.isCardAspectRatio($0)
                }

            guard let rect =
                cardRects.max(
                    by: {
                        ($0.boundingBox.width * $0.boundingBox.height)
                        <
                        ($1.boundingBox.width * $1.boundingBox.height)
                    }
                )
            else {

                DispatchQueue.main.async {
                    self.onRectangleDetected?(nil)
                }

                self.stableFrameCount = max(
                    0,
                    self.stableFrameCount - 1
                )

                return
            }

            let area =
                rect.boundingBox.width *
                rect.boundingBox.height

            print(
                "[OCR] ✅ Card rect",
                "area:",
                String(format: "%.3f", area),
                "stable:",
                self.stableFrameCount
            )

            DispatchQueue.main.async {
                self.onRectangleDetected?(rect)
            }

            if let last = self.lastRect {

                if self.isSameRect(rect, last) {

                    self.stableFrameCount += 1

                } else {

                    // Instead of resetting to zero,
                    // slowly decay stability

                    self.stableFrameCount = max(
                        0,
                        self.stableFrameCount - 1
                    )
                }

            } else {

                self.stableFrameCount = 1
            }

            self.lastRect = rect

            guard
                self.stableFrameCount >= self.requiredStableFrames
            else {
                return
            }

            print("[OCR] 📸 Stable card acquired")

            self.captureFullCard(
                from: pixelBuffer,
                rect: rect
            )
        }

        request.maximumObservations = 10
        request.minimumConfidence   = 0.45
        request.minimumAspectRatio  = 0.60
        request.maximumAspectRatio  = 0.80
        request.minimumSize         = 0.08
        request.quadratureTolerance = 30

        DispatchQueue.global(
            qos: .userInitiated
        ).async { [weak self] in

            guard let self else { return }

            if let known = self.workingOrientation {

                let handler = VNImageRequestHandler(
                    cvPixelBuffer: pixelBuffer,
                    orientation: known,
                    options: [:]
                )

                try? handler.perform([request])
                return
            }

            let orientations: [CGImagePropertyOrientation] = [
                .right,
                .up,
                .left,
                .down
            ]

            for orientation in orientations {

                let probe = VNDetectRectanglesRequest()

                probe.maximumObservations = 5
                probe.minimumConfidence   = 0.35
                probe.minimumAspectRatio  = 0.50
                probe.maximumAspectRatio  = 0.90
                probe.minimumSize         = 0.05

                let handler = VNImageRequestHandler(
                    cvPixelBuffer: pixelBuffer,
                    orientation: orientation,
                    options: [:]
                )

                try? handler.perform([probe])

                let found =
                    probe.results as? [VNRectangleObservation]
                    ?? []

                if !found.isEmpty {

                    print(
                        "[OCR] 🎯 Working orientation:",
                        orientation.debugName
                    )

                    self.workingOrientation = orientation

                    let realHandler =
                        VNImageRequestHandler(
                            cvPixelBuffer: pixelBuffer,
                            orientation: orientation,
                            options: [:]
                        )

                    try? realHandler.perform([request])

                    return
                }
            }

            print("[OCR] No rectangles found")
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

        var cardImage = UIImage(cgImage: cgImage)

        if cardImage.size.width > cardImage.size.height {

            UIGraphicsBeginImageContextWithOptions(
                CGSize(
                    width: cardImage.size.height,
                    height: cardImage.size.width
                ),
                false,
                cardImage.scale
            )

            guard let context = UIGraphicsGetCurrentContext() else {
                return
            }

            context.translateBy(
                x: cardImage.size.height / 2,
                y: cardImage.size.width / 2
            )

            context.rotate(by: -.pi / 2)

            cardImage.draw(
                in: CGRect(
                    x: -cardImage.size.width / 2,
                    y: -cardImage.size.height / 2,
                    width: cardImage.size.width,
                    height: cardImage.size.height
                )
            )

            if let rotated = UIGraphicsGetImageFromCurrentImageContext() {
                cardImage = rotated
            }

            UIGraphicsEndImageContext()
        }
        print(
            "[OCR] Normalised card size:",
            cardImage.size
        )

        recogniseCardName(from: cardImage) { [weak self] name in
            guard let self else { return }

            self.recognisedCardName = name

            print("[OCR] Card name: \(name ?? "none")")

            DispatchQueue.main.async {
                let artworkImage = self.cropArtwork(
                    from: cardImage
                )

                self.onCardImageCaptured?(
                    artworkImage
                )
            }
        }
    }
    
    private func cropArtwork(
        from image: UIImage
    ) -> UIImage {

        guard let cgImage = image.cgImage else {
            return image
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let artRect = CGRect(
            x: width * 0.08,
            y: height * 0.12,
            width: width * 0.84,
            height: height * 0.42
        )

        guard let cropped =
            cgImage.cropping(to: artRect)
        else {
            return image
        }

        return UIImage(
            cgImage: cropped
        )
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
    
    private func recogniseCardName(
        from image: UIImage,
        completion: @escaping (String?) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let request = VNRecognizeTextRequest { request, error in

            guard error == nil else {
                completion(nil)
                return
            }

            let observations =
                request.results as? [VNRecognizedTextObservation] ?? []

            let strings = observations.compactMap {
                $0.topCandidates(1).first?.string
            }

            // MTG card name is normally the first line
            let cardName = strings.first?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            completion(cardName)
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                options: [:]
            )

            try? handler.perform([request])
        }
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
