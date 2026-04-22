<<<<<<< HEAD
import Foundation
import Security

// MARK: - KeychainService

final class KeychainService {

    static let shared = KeychainService()
    private init() {}

    // MARK: - Keys

    enum Key: String {
        case geminiAPIKey = "com.tcgscanner.gemini_api_key"
    }

    // MARK: - Public API

    func save(_ value: String, for key: Key) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrAccount:     key.rawValue,
            kSecValueData:       data,
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing before saving
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func retrieve(_ key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrAccount:     key.rawValue,
            kSecReturnData:      true,
            kSecMatchLimit:      kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data
        else { return nil }

        return String(data: data, encoding: .utf8)
    }

    func delete(_ key: Key) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    var hasGeminiKey: Bool {
        retrieve(.geminiAPIKey) != nil
    }
}
=======
//
//  KeyChainService.swift
//  TcgScanner
//
//  Created by Joel James on 21/04/2026.
//

import Foundation
>>>>>>> 7d67abed8899bd6b484c1167ed5531a4fe6a2be0
