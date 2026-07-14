import Foundation

enum AppLog {
    static func debug(
        _ items: Any...,
        separator: String = " ",
        terminator: String = "\n"
    ) {
        #if DEBUG
        let message = items.map { String(describing: $0) }.joined(separator: separator)
        print(message, terminator: terminator)
        #endif
    }
}
