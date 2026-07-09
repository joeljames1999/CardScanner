import Foundation

enum PriceCurrency: String, CaseIterable, Codable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case cad = "CAD"
    case aud = "AUD"
    case jpy = "JPY"
    case chf = "CHF"

    var displayName: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .cad: return "Canadian Dollar"
        case .aud: return "Australian Dollar"
        case .jpy: return "Japanese Yen"
        case .chf: return "Swiss Franc"
        }
    }
}

final class CurrencySettings {

    static let shared = CurrencySettings()
    static let didChangeNotification = Notification.Name("CurrencySettingsDidChange")

    private enum Key {
        static let preferredCurrency = "preferredPriceCurrency"
    }

    private let defaults: UserDefaults

    var preferredCurrency: PriceCurrency {
        get {
            guard
                let rawValue = defaults.string(forKey: Key.preferredCurrency),
                let currency = PriceCurrency(rawValue: rawValue)
            else {
                return .usd
            }

            return currency
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.preferredCurrency)

            if newValue != .usd {
                Task {
                    await ExchangeRateService.shared.refreshRatesIfNeeded()
                }
            }

            NotificationCenter.default.post(
                name: Self.didChangeNotification,
                object: newValue
            )
        }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
}
