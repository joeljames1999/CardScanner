import Vision
import CoreImage
import UIKit

// MARK: - Card Detection Result

struct CardDetectionResult {
    let boundingBox: CGRect      // normalised rect in Vision coords (for overlay drawing)
    let cardName: String
}

// MARK: - OCR Service

final class OCRService {

    // MARK: Callbacks

    /// Called when a card rectangle is detected (even before OCR completes) — use for overlay
    var onRectangleDetected: ((CGRect?) -> Void)?
    /// Called when a card name is confidently identified
    var onCardDetected: ((String) -> Void)?

    // MARK: Private

    private let ciContext = CIContext()

    // Debounce — don't fire for the same name repeatedly
    private var lastDetectedName: String = ""
    private var lastDetectionTime: Date  = .distantPast
    private let cooldownInterval: TimeInterval = 3.0

    // Throttle OCR — it's expensive
    private var lastOCRTime: Date = .distantPast
    private let ocrInterval: TimeInterval = 0.4

    // MARK: Public

    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        detectRectangle(in: pixelBuffer)
    }

    func resetCooldown() {
        lastDetectedName = ""
        lastDetectionTime = .distantPast
    }

    // MARK: Step 1 — Rectangle Detection

    private func detectRectangle(in pixelBuffer: CVPixelBuffer) {
        let request = VNDetectRectanglesRequest { [weak self] req, error in
            guard let self else { return }

            guard let results = req.results as? [VNRectangleObservation],
                  let best = results.first
            else {
                DispatchQueue.main.async { self.onRectangleDetected?(nil) }
                return
            }

            // Filter by MTG card aspect ratio (63:88 = ~0.716)
            // Allow some tolerance for angle/perspective
            let aspect = best.boundingBox.width / best.boundingBox.height
            guard aspect > 0.55 && aspect < 0.85 else {
                DispatchQueue.main.async { self.onRectangleDetected?(nil) }
                return
            }

            // Confidence check
            guard best.confidence > 0.85 else { return }

            DispatchQueue.main.async {
                self.onRectangleDetected?(best.boundingBox)
            }

            // Throttle OCR
            let now = Date()
            guard now.timeIntervalSince(self.lastOCRTime) >= self.ocrInterval else { return }
            self.lastOCRTime = now

            self.runOCR(on: pixelBuffer, rectangle: best)
        }

        request.minimumConfidence       = 0.8
        request.minimumAspectRatio      = 0.55
        request.maximumAspectRatio      = 0.85
        request.minimumSize             = 0.2
        request.maximumObservations     = 1

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: Step 2 — Perspective Correction + OCR on name region

    private func runOCR(on pixelBuffer: CVPixelBuffer, rectangle: VNRectangleObservation) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let width  = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        // Convert Vision normalised coords (bottom-left origin) to CIImage coords
        func toCI(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * width, y: point.y * height)
        }

        // Perspective correction filter
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: toCI(rectangle.topLeft)),     forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: toCI(rectangle.topRight)),    forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: toCI(rectangle.bottomRight)), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: toCI(rectangle.bottomLeft)),  forKey: "inputBottomLeft")

        guard let corrected = filter.outputImage else { return }

        // Crop to top 15% of the corrected card — this is always where the name is on MTG cards
        let nameStripHeight = corrected.extent.height * 0.15
        let nameRegion = CGRect(
            x: corrected.extent.minX,
            y: corrected.extent.maxY - nameStripHeight,   // top strip (CIImage Y is flipped)
            width: corrected.extent.width,
            height: nameStripHeight
        )
        let nameStrip = corrected.cropped(to: nameRegion)

        guard let cgImage = ciContext.createCGImage(nameStrip, from: nameStrip.extent) else { return }

        let ocrRequest = VNRecognizeTextRequest { [weak self] req, _ in
            guard let self,
                  let results = req.results as? [VNRecognizedTextObservation]
            else { return }

            let candidates = results
                .compactMap { $0.topCandidates(1).first }
                .filter { $0.confidence > 0.5 }
                .map { $0.string }

            guard let name = candidates.first, !name.isEmpty else { return }

            self.handleDetectedName(name)
        }

        ocrRequest.recognitionLevel       = .accurate
        ocrRequest.usesLanguageCorrection = true
        ocrRequest.recognitionLanguages   = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([ocrRequest])
    }

    // MARK: Step 3 — Debounce & fire callback

    private func handleDetectedName(_ name: String) {
        let now = Date()

        // Same card within cooldown window — ignore
        if name.lowercased() == lastDetectedName.lowercased(),
           now.timeIntervalSince(lastDetectionTime) < cooldownInterval {
            return
        }

        lastDetectedName  = name
        lastDetectionTime = now

        DispatchQueue.main.async {
            self.onCardDetected?(name)
        }
    }
}
