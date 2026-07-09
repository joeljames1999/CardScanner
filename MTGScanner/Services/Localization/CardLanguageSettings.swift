import Foundation

enum CardLanguage: String, CaseIterable, Codable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case japanese = "ja"
    case korean = "ko"
    case russian = "ru"
    case simplifiedChinese = "zhs"
    case traditionalChinese = "zht"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .russian: return "Russian"
        case .simplifiedChinese: return "Simplified Chinese"
        case .traditionalChinese: return "Traditional Chinese"
        }
    }
}

final class CardLanguageSettings {

    static let shared = CardLanguageSettings()
    static let didChangeNotification = Notification.Name("CardLanguageSettingsDidChange")

    private enum Key {
        static let preferredLanguage = "preferredCardLanguage"
    }

    private let defaults: UserDefaults

    var preferredLanguage: CardLanguage {
        get {
            guard
                let rawValue = defaults.string(forKey: Key.preferredLanguage),
                let language = CardLanguage(rawValue: rawValue)
            else {
                return .english
            }

            return language
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.preferredLanguage)
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
