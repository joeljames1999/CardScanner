import Foundation

struct ExchangeRateSnapshot: Codable {
    let base: String
    let date: String
    let rates: [String: Double]
}

private struct ExchangeRateQuote: Decodable {
    let base: String
    let date: String
    let quote: String
    let rate: Double
}

final class ExchangeRateService {

    static let shared = ExchangeRateService()
    static let didRefreshNotification = Notification.Name("ExchangeRateServiceDidRefresh")

    private enum Key {
        static let cachedSnapshot = "cachedExchangeRateSnapshot"
    }

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let userDefaults: UserDefaults
    private var cachedSnapshot: ExchangeRateSnapshot?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.cachedSnapshot = Self.loadSnapshot(from: userDefaults)
    }

    func refreshRatesIfNeeded() async {
        if let cachedSnapshot,
           Calendar.current.isDateInToday(date(from: cachedSnapshot.date) ?? .distantPast) {
            return
        }

        await refreshRates()
    }

    func refreshRates() async {
        let quoteCodes = PriceCurrency.allCases
            .filter { $0 != .usd }
            .map(\.rawValue)
            .joined(separator: ",")

        guard var components = URLComponents(string: "https://api.frankfurter.dev/v2/rates") else {
            return
        }

        components.queryItems = [
            URLQueryItem(name: "base", value: PriceCurrency.usd.rawValue),
            URLQueryItem(name: "quotes", value: quoteCodes)
        ]

        guard let url = components.url else {
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let quotes = try decoder.decode([ExchangeRateQuote].self, from: data)
            let snapshot = makeSnapshot(from: quotes)
            cachedSnapshot = snapshot

            if let encoded = try? encoder.encode(snapshot) {
                userDefaults.set(encoded, forKey: Key.cachedSnapshot)
            }

            NotificationCenter.default.post(
                name: Self.didRefreshNotification,
                object: snapshot
            )
        } catch {
            print("[ExchangeRateService] Refresh failed:", error)
        }
    }

    private func makeSnapshot(
        from quotes: [ExchangeRateQuote]
    ) -> ExchangeRateSnapshot {

        let base = quotes.first?.base ?? PriceCurrency.usd.rawValue
        let date = quotes.first?.date ?? dateString(from: Date())
        let rates = Dictionary(
            uniqueKeysWithValues: quotes.map {
                ($0.quote, $0.rate)
            }
        )

        return ExchangeRateSnapshot(
            base: base,
            date: date,
            rates: rates
        )
    }

    func convertedAmount(
        usd amount: Double,
        to currency: PriceCurrency
    ) -> Double? {

        guard currency != .usd else {
            return amount
        }

        guard let rate = cachedSnapshot?.rates[currency.rawValue] else {
            return nil
        }

        return amount * rate
    }

    private static func loadSnapshot(
        from userDefaults: UserDefaults
    ) -> ExchangeRateSnapshot? {

        guard let data = userDefaults.data(forKey: Key.cachedSnapshot) else {
            return nil
        }

        return try? JSONDecoder().decode(
            ExchangeRateSnapshot.self,
            from: data
        )
    }

    private func date(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
