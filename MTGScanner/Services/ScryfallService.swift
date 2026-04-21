import Foundation

// MARK: - Scryfall API Service

final class ScryfallService {

    // MARK: Errors

    enum ScryfallError: LocalizedError {
        case cardNotFound
        case rateLimited
        case networkError(Error)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .cardNotFound:     return "Card not found. Try holding the card steadier."
            case .rateLimited:      return "Too many requests — please wait a moment."
            case .networkError(let e): return "Network error: \(e.localizedDescription)"
            case .decodingError(let e): return "Data error: \(e.localizedDescription)"
            }
        }
    }

    // MARK: Private

    private let baseURL = "https://api.scryfall.com"
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        // Scryfall asks for a descriptive User-Agent
        config.httpAdditionalHeaders = ["User-Agent": "MTGScanner-iOS/1.0"]
        return URLSession(configuration: config)
    }()

    // Debounce — avoid hammering the API with near-identical queries
    private var lastQuery: String = ""
    private var lastResult: MTGCard?

    // MARK: Public API

    /// Fetch a card by fuzzy name match (tolerates minor OCR errors).
    func fetchCard(named query: String) async throws -> MTGCard {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Return cached result for the same query
        if cleaned.lowercased() == lastQuery.lowercased(), let cached = lastResult {
            return cached
        }

        guard let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/cards/named?fuzzy=\(encoded)")
        else {
            throw ScryfallError.cardNotFound
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw ScryfallError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ScryfallError.networkError(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200:
            break
        case 404:
            throw ScryfallError.cardNotFound
        case 429:
            throw ScryfallError.rateLimited
        default:
            throw ScryfallError.networkError(URLError(.badServerResponse))
        }

        do {
            let card = try JSONDecoder().decode(MTGCard.self, from: data)
            lastQuery  = cleaned
            lastResult = card
            return card
        } catch {
            throw ScryfallError.decodingError(error)
        }
    }

    /// Search cards by partial name — useful for a search screen.
    func searchCards(query: String) async throws -> [MTGCard] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/cards/search?q=\(encoded)&order=name")
        else { return [] }

        let (data, _) = try await session.data(from: url)

        struct SearchResponse: Decodable {
            let data: [MTGCard]
        }

        let result = try JSONDecoder().decode(SearchResponse.self, from: data)
        return result.data
    }
}
