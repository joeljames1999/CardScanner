import Foundation
import UIKit

final class ScryfallService {

    enum ScryfallError: LocalizedError {
        case cardNotFound
        case rateLimited
        case networkError(Error)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .cardNotFound:
                return "Card not found"
            case .rateLimited:
                return "Too many requests"
            case .networkError(let error):
                return error.localizedDescription
            case .decodingError(let error):
                return error.localizedDescription
            }
        }
    }

    private let baseURL = "https://api.scryfall.com"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "MTGScanner-iOS/1.0"
        ]
        return URLSession(configuration: config)
    }()

    // MARK: OCR Lookup

    func fetchCard(named query: String) async throws -> MTGCard {
        guard
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "\(baseURL)/cards/named?fuzzy=\(encoded)")
        else {
            throw ScryfallError.cardNotFound
        }

        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw ScryfallError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ScryfallError.cardNotFound
        }

        switch http.statusCode {
        case 200:
            break
        case 404:
            throw ScryfallError.cardNotFound
        case 429:
            throw ScryfallError.rateLimited
        default:
            throw ScryfallError.cardNotFound
        }

        do {
            return try JSONDecoder().decode(MTGCard.self, from: data)
        } catch {
            throw ScryfallError.decodingError(error)
        }
    }

    // MARK: Image Identify

    func identifyCard(image: UIImage) async throws -> MTGCard {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ScryfallError.cardNotFound
        }

        let url = URL(string: "\(baseURL)/cards/identify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString

        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"card.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, _) = try await session.data(for: request)

        do {
            return try JSONDecoder().decode(MTGCard.self, from: data)
        } catch {
            throw ScryfallError.cardNotFound
        }
    }
}
