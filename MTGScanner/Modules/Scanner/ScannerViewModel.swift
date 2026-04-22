import UIKit
import Vision

final class ScannerViewModel {

    private var isProcessing = false

    func processFrame(_ image: UIImage) {
        guard !isProcessing else { return }
        isProcessing = true

        recognizeText(from: image) { [weak self] text in
            defer { self?.isProcessing = false }

            guard let text = text, !text.isEmpty else {
                print("❌ No text found")
                return
            }

            print("🔍 OCR TEXT:", text)

            if let cardName = self?.extractCardName(from: text) {
                print("✅ Detected card:", cardName)
                // TODO: Call Scryfall or your DB here
            } else {
                print("❌ Could not identify card")
            }
        }
    }
}

// MARK: - OCR

private extension ScannerViewModel {

    func recognizeText(from image: UIImage, completion: @escaping (String?) -> Void) {

        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let request = VNRecognizeTextRequest { request, _ in

            let observations = request.results as? [VNRecognizedTextObservation]

            let text = observations?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")

            completion(text)
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        try? handler.perform([request])
    }

    func extractCardName(from text: String) -> String? {
        let lines = text.components(separatedBy: "\n")

        // MTG card name is usually one of the first lines
        return lines.first(where: { $0.count > 3 && $0.count < 40 })
    }
}
