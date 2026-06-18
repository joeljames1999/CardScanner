import Vision
import UIKit
final class OCRService {

    var onRectangleDetected:
        ((VNRectangleObservation?) -> Void)?

    var onCardImageCaptured:
        ((UIImage) -> Void)?

    private let detector =
        CardRectangleDetector()

    private let captureService =
        CardCaptureService()

    private let nameRecognizer =
        CardNameRecognizer()

    private var workingOrientation:
        CGImagePropertyOrientation?

    private var isLocked = false

    private(set) var recognisedCardName: String?

    func processFrame(
        _ pixelBuffer: CVPixelBuffer
    ) {

        guard !isLocked else {
            return
        }

        detectCard(
            in: pixelBuffer
        )
    }

    func resetForNextScan() {

        isLocked = false

        recognisedCardName = nil

        detector.reset()
    }

    func resetCooldown() {
        resetForNextScan()
    }
}
extension OCRService {
    private func detectCard(
        in pixelBuffer: CVPixelBuffer
    ) {
        
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            
            guard let self else { return }
            
            let rects =
            request.results as? [VNRectangleObservation]
            ?? []
            
            let largestRect = rects.max {
                ($0.boundingBox.width * $0.boundingBox.height)
                <
                    ($1.boundingBox.width * $1.boundingBox.height)
            }
            
            DispatchQueue.main.async {
                self.onRectangleDetected?(largestRect)
            }
            
            guard let stableRect =
                    self.detector.process(rects: rects)
            else {
                return
            }
            
            print("[OCR] 📸 Stable card acquired")
            
            self.captureCard(
                from: pixelBuffer,
                rect: stableRect
            )
        }
        
        request.maximumObservations = 10
        request.minimumConfidence = 0.45
        request.minimumAspectRatio = 0.60
        request.maximumAspectRatio = 0.80
        request.minimumSize = 0.08
        request.quadratureTolerance = 30
        
        DispatchQueue.global(
            qos: .userInitiated
        ).async { [weak self] in
            
            guard let self else { return }
            
            if let knownOrientation =
                self.workingOrientation {
                
                let handler =
                VNImageRequestHandler(
                    cvPixelBuffer: pixelBuffer,
                    orientation: knownOrientation,
                    options: [:]
                )
                
                try? handler.perform([request])
                return
            }
            
            let orientations:
            [CGImagePropertyOrientation] = [
                .right,
                .up,
                .left,
                .down
            ]
            
            for orientation in orientations {
                
                let probe =
                VNDetectRectanglesRequest()
                
                probe.maximumObservations = 5
                probe.minimumConfidence = 0.35
                probe.minimumAspectRatio = 0.50
                probe.maximumAspectRatio = 0.90
                probe.minimumSize = 0.05
                
                let handler =
                VNImageRequestHandler(
                    cvPixelBuffer: pixelBuffer,
                    orientation: orientation,
                    options: [:]
                )
                
                try? handler.perform([probe])
                
                let results =
                probe.results as? [VNRectangleObservation]
                ?? []
                
                if !results.isEmpty {
                    
                    print(
                        "[OCR] 🎯 Working orientation:",
                        orientation
                    )
                    
                    self.workingOrientation =
                    orientation
                    
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
}

extension OCRService {
    private func captureCard(
        from pixelBuffer: CVPixelBuffer,
        rect: VNRectangleObservation
    ) {
        
        guard !isLocked else {
            return
        }
        
        isLocked = true
        
        print("[OCR] 📸 Capturing card image...")
        
        let orientation =
        workingOrientation ?? .right
        
        guard let cardImage =
                captureService.capture(
                    from: pixelBuffer,
                    rect: rect,
                    orientation: orientation
                )
        else {
            
            print(
                "[OCR] ❌ Failed to capture card"
            )
            
            isLocked = false
            return
        }
        
        print(
            "[OCR] ✅ Card captured — size:",
            cardImage.size
        )
        
        Task { [weak self] in
            
            guard let self else {
                return
            }
            
            let cardName =
            await nameRecognizer.recognise(
                from: cardImage
            )
            
            recognisedCardName = cardName
            
            print(
                "[OCR] Card name:",
                cardName ?? "none"
            )
            
            await MainActor.run {
                
                self.onCardImageCaptured?(
                    cardImage
                )
            }
        }
    }
}
