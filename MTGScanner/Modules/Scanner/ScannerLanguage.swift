import Foundation

struct ScannerLanguage: Hashable {
    let code: String
    let name: String

    var shortName: String {
        switch code {
        case "zhs": return "简"
        case "zht": return "繁"
        case "ja": return "日"
        case "ko": return "한"
        case "he": return "עב"
        case "grc": return "GR"
        default:
            return code.prefix(2).uppercased()
        }
    }
}

enum ScannerLanguages {
    static let fallback = ScannerLanguage(code: "en", name: "English")

    static let all: [ScannerLanguage] = [
        ScannerLanguage(code: "en", name: "English"),
        ScannerLanguage(code: "es", name: "Spanish"),
        ScannerLanguage(code: "fr", name: "French"),
        ScannerLanguage(code: "de", name: "German"),
        ScannerLanguage(code: "it", name: "Italian"),
        ScannerLanguage(code: "pt", name: "Portuguese"),
        ScannerLanguage(code: "ja", name: "Japanese"),
        ScannerLanguage(code: "ko", name: "Korean"),
        ScannerLanguage(code: "ru", name: "Russian"),
        ScannerLanguage(code: "zhs", name: "Simplified Chinese"),
        ScannerLanguage(code: "zht", name: "Traditional Chinese"),
        ScannerLanguage(code: "he", name: "Hebrew"),
        ScannerLanguage(code: "la", name: "Latin"),
        ScannerLanguage(code: "grc", name: "Ancient Greek"),
        ScannerLanguage(code: "ar", name: "Arabic"),
        ScannerLanguage(code: "sa", name: "Sanskrit"),
        ScannerLanguage(code: "ph", name: "Phyrexian")
    ]

    static func language(for code: String?) -> ScannerLanguage {
        guard let code else {
            return fallback
        }

        return all.first {
            $0.code.caseInsensitiveCompare(code) == .orderedSame
        } ?? ScannerLanguage(code: code, name: code.uppercased())
    }

    static func available(from codes: [String]) -> [ScannerLanguage] {
        var seen = Set<String>()
        var languages: [ScannerLanguage] = []

        for code in codes {
            let language = language(for: code)
            guard seen.insert(language.code).inserted else {
                continue
            }

            languages.append(language)
        }

        return languages.isEmpty ? [fallback] : languages
    }
}
