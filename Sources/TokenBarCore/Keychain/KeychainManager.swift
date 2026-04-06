#if canImport(Security)
import Security
import Foundation

public enum KeychainError: Error, Sendable {
    case itemNotFound
    case duplicateItem
    case unexpectedData
    case unhandledError(OSStatus)
}

public actor KeychainManager {
    public static let shared = KeychainManager()
    private let service: String

    public init() {
        self.service = "com.tokenbar"
    }

    /// Test-only initializer — use a custom service to isolate from production keychain data.
    init(service: String) {
        self.service = service
    }

    public func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            // Update existing
            let updateQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: key,
            ]
            let attributes: [CFString: Any] = [kSecValueData: data]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledError(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unhandledError(status)
        }
    }

    public func load(key: String) throws -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status)
        }

        guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return string
    }

    public func delete(key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }

    public func exists(key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: false,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}

#else
// Linux stub — stores credentials in memory only (for CLI testing)
import Foundation

public enum KeychainError: Error, Sendable {
    case itemNotFound
    case duplicateItem
    case unexpectedData
    case unhandledError(Int32)
}

public actor KeychainManager {
    public static let shared = KeychainManager()
    private var store: [String: String] = [:]

    public init() {}

    /// Test-only initializer — mirrors the macOS API; service is unused on Linux (store is in-memory).
    init(service: String) {}

    public func save(key: String, value: String) throws {
        store[key] = value
    }

    public func load(key: String) throws -> String {
        guard let value = store[key] else {
            throw KeychainError.itemNotFound
        }
        return value
    }

    public func delete(key: String) throws {
        store.removeValue(forKey: key)
    }

    public func exists(key: String) -> Bool {
        store[key] != nil
    }
}
#endif
