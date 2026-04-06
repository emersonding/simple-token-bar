public protocol UsageProviding: Actor {
    var providerID: ProviderID { get }
    func fetchUsage() async throws -> UsageSnapshot
}

public enum FetchError: Error, Sendable {
    case notConfigured          // no credentials set up
    case authExpired            // cookie/token expired, user must re-login
    case networkError(String)   // transient network failure — stores error description
    case parseError(String)     // API response changed/unexpected format
    case rateLimited            // too many requests
}
