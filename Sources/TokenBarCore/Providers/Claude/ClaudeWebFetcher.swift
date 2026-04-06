#if os(macOS)
import Foundation
import Logging

private let logger = Logger(label: "com.tokenbar.claude")

public actor ClaudeWebFetcher: UsageProviding {
    public static let shared = ClaudeWebFetcher()

    public let providerID: ProviderID = .claude

    private let cookieManager: BrowserCookieManager
    private let session: URLSession

    public init(cookieManager: BrowserCookieManager = .shared) {
        self.cookieManager = cookieManager
        self.session = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 15
            return config
        }())
    }

    /// Designated initializer for unit tests — accepts a pre-configured URLSession.
    init(cookieManager: BrowserCookieManager, session: URLSession) {
        self.cookieManager = cookieManager
        self.session = session
    }

    public func fetchUsage() async throws -> UsageSnapshot {
        guard let sessionKey = try await cookieManager.cookie(named: "sessionKey", domain: "claude.ai") else {
            throw FetchError.notConfigured
        }

        let orgUUID = try await fetchOrgUUID(sessionKey: sessionKey)
        let usageResponse = try await fetchUsageWindow(orgUUID: orgUUID, sessionKey: sessionKey)
        let spendResponse = try? await fetchSpendLimit(orgUUID: orgUUID, sessionKey: sessionKey)

        let primary: RateWindow? = usageResponse.fiveHour.map {
            RateWindow(usedPercent: $0.utilization, windowMinutes: 300, resetsAt: $0.resetsAt)
        }
        let secondary: RateWindow? = usageResponse.sevenDay.map {
            RateWindow(usedPercent: $0.utilization, windowMinutes: 7 * 24 * 60, resetsAt: $0.resetsAt)
        }

        var credits: CreditsSnapshot? = nil
        if let spend = spendResponse, spend.isEnabled, let limit = spend.monthlyCreditLimit {
            let remaining = limit - spend.usedCredits
            credits = CreditsSnapshot(remaining: remaining, currency: spend.currency)
        }

        return UsageSnapshot(
            providerID: .claude,
            primary: primary,
            secondary: secondary,
            credits: credits
        )
    }

    // MARK: - Private helpers

    private func fetchOrgUUID(sessionKey: String) async throws -> String {
        let url = URL(string: "https://claude.ai/api/organizations")!
        let data = try await get(url: url, sessionKey: sessionKey)
        let orgs = try makeDecoder().decode([ClaudeOrganization].self, from: data)
        guard let first = orgs.first else {
            throw FetchError.parseError("No organizations returned")
        }
        return first.uuid
    }

    private func fetchUsageWindow(orgUUID: String, sessionKey: String) async throws -> ClaudeUsageResponse {
        let url = URL(string: "https://claude.ai/api/organizations/\(orgUUID)/usage")!
        let data = try await get(url: url, sessionKey: sessionKey)
        do {
            return try makeDecoder().decode(ClaudeUsageResponse.self, from: data)
        } catch {
            logger.error("Claude usage parse error", metadata: ["raw": .string(String(data: data, encoding: .utf8) ?? "<binary>")])
            throw FetchError.parseError("Failed to parse usage response: \(error)")
        }
    }

    private func fetchSpendLimit(orgUUID: String, sessionKey: String) async throws -> ClaudeSpendLimitResponse {
        let url = URL(string: "https://claude.ai/api/organizations/\(orgUUID)/overage_spend_limit")!
        let data = try await get(url: url, sessionKey: sessionKey)
        return try makeDecoder().decode(ClaudeSpendLimitResponse.self, from: data)
    }

    private func get(url: URL, sessionKey: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("TokenBar/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FetchError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FetchError.networkError("Invalid response type")
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401, 403:
            throw FetchError.authExpired
        case 429:
            throw FetchError.rateLimited
        default:
            throw FetchError.networkError("HTTP \(http.statusCode)")
        }
    }
}

/// Creates a JSONDecoder with ISO8601 date decoding (with and without fractional seconds).
private func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) { return date }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
    }
    return decoder
}
#endif
