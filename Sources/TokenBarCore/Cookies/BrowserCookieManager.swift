#if os(macOS)
import Foundation
import SweetCookieKit

public enum CookieError: Error, Sendable {
    case notFound
    case accessDenied
    case safariRequiresFullDiskAccess
}

public actor BrowserCookieManager {
    public static let shared = BrowserCookieManager()

    private var config: CookieConfig
    private var cache: [String: (value: String, expiry: Date)] = [:]
    private let cacheDuration: TimeInterval = 5 * 60  // 5 minutes

    public init(config: CookieConfig = CookieConfig()) {
        self.config = config
    }

    public func updateConfig(_ config: CookieConfig) {
        self.config = config
    }

    public func cookie(named name: String, domain: String) async throws -> String? {
        let cacheKey = "\(domain):\(name)"

        // Check cache
        if let cached = cache[cacheKey], cached.expiry > Date() {
            return cached.value
        }

        var browsers: [Browser] = []
        if config.enableChrome  { browsers.append(.chrome) }
        if config.enableFirefox { browsers.append(.firefox) }
        if config.enableSafari  { browsers.append(.safari) }

        let client = BrowserCookieClient()
        let query = BrowserCookieQuery(domains: [domain], domainMatch: .suffix)

        for browser in browsers {
            do {
                let storeRecords = try client.records(matching: query, in: browser)
                for storeRecord in storeRecords {
                    if let match = storeRecord.records.first(where: { $0.name == name }) {
                        let expiry = Date().addingTimeInterval(cacheDuration)
                        cache[cacheKey] = (value: match.value, expiry: expiry)
                        return match.value
                    }
                }
            } catch let cookieError as BrowserCookieError {
                if case .accessDenied(let b, _) = cookieError, b == .safari {
                    throw CookieError.safariRequiresFullDiskAccess
                }
                // Continue to next browser on notFound/loadFailed
            } catch {
                // Continue to next browser
            }
        }

        return nil
    }

    public func clearCache() {
        cache.removeAll()
    }

    /// Seeds a cookie directly into the in-memory cache, bypassing browser lookup. For testing only.
    func seedCookieForTesting(name: String, domain: String, value: String) {
        let cacheKey = "\(domain):\(name)"
        cache[cacheKey] = (value: value, expiry: Date().addingTimeInterval(3600))
    }
}

#else
// Linux stub — no browser cookie support
import Foundation

public enum CookieError: Error, Sendable {
    case notFound
    case accessDenied
    case safariRequiresFullDiskAccess
}

public actor BrowserCookieManager {
    public static let shared = BrowserCookieManager()
    private var config: CookieConfig

    public init(config: CookieConfig = CookieConfig()) {
        self.config = config
    }

    public func updateConfig(_ config: CookieConfig) {
        self.config = config
    }

    public func cookie(named name: String, domain: String) async throws -> String? {
        return nil
    }

    public func clearCache() {}
}
#endif
