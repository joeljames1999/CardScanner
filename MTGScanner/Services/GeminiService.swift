<<<<<<< HEAD
import UIKit
import Foundation

// MARK: - GeminiService
// Sends a captured card image to Gemini Vision and returns the identified
// card name + set code. Uses the Gemini 1.5 Flash model (free tier).

final class GeminiService {

    // MARK: - Errors

    enum GeminiError: LocalizedError {
        case noAPIKey
        case imageEncodingFailed
        case networkError(Error)
        case noResponse
        case cardNotIdentified
        case decodingError

        var errorDescription: String? {
            switch self {
            case .noAPIKey:             return "No Gemini API key set. Add one in Menu → Settings."
            case .imageEncodingFailed:  return "Could not encode image."
            case .networkError(let e):  return "Network error: \(e.localizedDescription)"
            case .noResponse:           return "No response from Gemini."
            case .cardNotIdentified:    return "Could not identify card — try better lighting or a flatter angle."
            case .decodingError:        return "Could not parse Gemini response."
            }
        }
    }

    // MARK: - Result

    struct CardIdentification {
        let name: String
        let setCode: String?   // may not always be returned
        let confidence: String // "high" | "medium" | "low"
    }

    // MARK: - Private

    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"

    private var apiKey: String? {
        KeychainService.shared.retrieve(.geminiAPIKey)
    }

    // MARK: - Public

    /// Identify a Magic: The Gathering card from a UIImage.
    /// Crops to the detected card rect before sending to reduce token usage.
    func identifyCard(from image: UIImage) async throws -> CardIdentification {
        guard let key = apiKey else { throw GeminiError.noAPIKey }

        // Resize to max 768px on the longest side — enough detail, keeps payload small
        let resized = image.resizedForUpload(maxDimension: 768)

        guard let imageData = resized.jpegData(compressionQuality: 0.85) else {
            throw GeminiError.imageEncodingFailed
        }

        let base64Image = imageData.base64EncodedString()

        // Prompt engineered for reliable structured output
        let prompt = """
        You are an expert Magic: The Gathering card identifier.
        
        Look at this image carefully. It contains a Magic: The Gathering card.
        
        Identify the card and respond ONLY with a valid JSON object in exactly this format:
        {
          "name": "exact card name as printed on the card",
          "set_code": "3-4 letter set code in lowercase (e.g. lea, eld, neo)",
          "confidence": "high or medium or low"
        }
        
        Rules:
        - "name" must be the exact printed name on the card
        - If the card has two faces, give only the front face name
        - If you cannot identify the card, return {"name": "", "set_code": "", "confidence": "low"}
        - Return ONLY the JSON, no other text, no markdown, no explanation
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature":     0.1,   // low temp for factual responses
                "topP":            0.8,
                "maxOutputTokens": 100    // we only need a tiny JSON blob
            ]
        ]

        guard let url = URL(string: "\(endpoint)?key=\(key)") else {
            throw GeminiError.networkError(URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw GeminiError.networkError(error)
        }

        let data: Data
        do {
            let (responseData, _) = try await URLSession.shared.data(for: request)
            data = responseData
        } catch {
            throw GeminiError.networkError(error)
        }

        return try parseResponse(data)
    }

    // MARK: - Response Parsing

    private func parseResponse(_ data: Data) throws -> CardIdentification {
        // Gemini wraps the output in candidates → content → parts → text
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String
        else {
            throw GeminiError.noResponse
        }

        // Strip any markdown fences just in case
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String]
        else {
            throw GeminiError.decodingError
        }

        let name = parsed["name"] ?? ""
        guard !name.isEmpty else { throw GeminiError.cardNotIdentified }

        return CardIdentification(
            name:       name,
            setCode:    parsed["set_code"].flatMap { $0.isEmpty ? nil : $0 },
            confidence: parsed["confidence"] ?? "medium"
        )
    }
}

// MARK: - UIImage resize helper

private extension UIImage {
    func resizedForUpload(maxDimension: CGFloat) -> UIImage {
        let size = self.size
        let longer = max(size.width, size.height)
        guard longer > maxDimension else { return self }

        let scale  = maxDimension / longer
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
=======
//
//  GeminiService.swift
//  TcgScanner
//
//  Created by Joel James on 21/04/2026.
//

import Foundation
>>>>>>> 7d67abed8899bd6b484c1167ed5531a4fe6a2be0
