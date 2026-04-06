import Foundation
import Logging

private let logger = Logger(label: "com.tokenbar.openai")

public actor OpenAIAPIFetcher: UsageProviding {
    public static let shared = OpenAIAPIFetcher()

    public let providerID: ProviderID = .openai

    private let keychainManager: KeychainManager
    private let session: URLSession
    private var cachedOAuthToken: String?

    public init(keychainManager: KeychainManager = .shared) {
        self.keychainManager = keychainManager
        self.session = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 15
            return config
        }())
    }

    /// Designated initializer for unit tests — accepts a pre-configured URLSession.
    init(keychainManager: KeychainManager, session: URLSession) {
        self.keychainManager = keychainManager
        self.session = session
    }

    public func fetchUsage() async throws -> UsageSnapshot {
        // Strategy 1: Try API key (gives billing data)
        if let snapshot = try? await fetchViaAPIKey() {
            return snapshot
        }

        // Strategy 2: Try Codex CLI RPC (gives rate limits)
        if let snapshot = try? await fetchViaCLI() {
            return snapshot
        }

        // Strategy 3: Try Codex OAuth (gives account info only)
        if let snapshot = try? await fetchViaOAuth() {
            return snapshot
        }

        throw FetchError.notConfigured
    }

    // MARK: - Strategy 1: API Key (billing endpoints)

    private func fetchViaAPIKey() async throws -> UsageSnapshot {
        let apiKey: String
        do {
            apiKey = try await keychainManager.load(key: "openai.apiKey")
            guard !apiKey.isEmpty else { throw FetchError.notConfigured }
        } catch KeychainError.itemNotFound {
            throw FetchError.notConfigured
        }

        let subscription = try await fetchSubscription(token: apiKey)
        let usage = try await fetchMonthUsage(token: apiKey)

        let usedDollars = usage.totalUsage / 100.0
        let hardLimit = subscription.hardLimitUSD
        let usedPercent = hardLimit > 0 ? (usedDollars / hardLimit * 100) : 0
        let remaining = hardLimit - usedDollars

        return UsageSnapshot(
            providerID: .openai,
            primary: RateWindow(usedPercent: usedPercent),
            secondary: nil,
            credits: CreditsSnapshot(
                remaining: remaining,
                currency: "USD",
                events: [],
                updatedAt: Date()
            ),
            identity: ProviderIdentity(
                providerID: .openai,
                accountEmail: nil,
                organization: subscription.plan.title
            )
        )
    }

    // MARK: - Strategy 2: Codex CLI RPC (rate limits via `codex app-server`)

    private func fetchViaCLI() async throws -> UsageSnapshot {
        guard let response = await CodexCLIFetcher.fetchRateLimits(),
              let limits = response.rateLimits else {
            throw FetchError.notConfigured
        }

        let primary: RateWindow? = limits.primary.map {
            RateWindow(
                usedPercent: $0.usedPercent,
                windowMinutes: $0.windowDurationMins,
                resetsAt: $0.resetsAtDate
            )
        }

        let secondary: RateWindow? = limits.secondary.map {
            RateWindow(
                usedPercent: $0.usedPercent,
                windowMinutes: $0.windowDurationMins,
                resetsAt: $0.resetsAtDate
            )
        }

        var credits: CreditsSnapshot?
        if let c = limits.credits, let balanceStr = c.balance, let balance = Double(balanceStr), balance > 0 {
            credits = CreditsSnapshot(
                remaining: balance,
                currency: "credits",
                events: [],
                updatedAt: Date()
            )
        }

        let planLabel = limits.planType.map { "Codex (\($0))" } ?? "Codex"

        return UsageSnapshot(
            providerID: .openai,
            primary: primary,
            secondary: secondary,
            credits: credits,
            identity: ProviderIdentity(
                providerID: .openai,
                accountEmail: nil,
                organization: planLabel
            )
        )
    }

    // MARK: - Strategy 3: Codex OAuth (~/.codex/auth.json → /v1/me, account info only)

    private func fetchViaOAuth() async throws -> UsageSnapshot {
        let token = try resolveOAuthToken()
        let me = try await fetchMe(token: token)

        let planType = me.chatgptPlanType ?? "unknown"
        let email = me.email ?? "unknown"

        logger.info("OpenAI account: \(email), plan: \(planType)")

        return UsageSnapshot(
            providerID: .openai,
            primary: nil,
            secondary: nil,
            credits: nil,
            identity: ProviderIdentity(
                providerID: .openai,
                accountEmail: email,
                organization: "Plan: \(planType)"
            )
        )
    }

    private func resolveOAuthToken() throws -> String {
        if let cached = cachedOAuthToken {
            return cached
        }

        guard let credentials = CodexOAuthCredentials.load() else {
            throw FetchError.notConfigured
        }

        cachedOAuthToken = credentials.accessToken
        return credentials.accessToken
    }

    private func fetchMe(token: String) async throws -> OpenAIMeResponse {
        let url = URL(string: "https://api.openai.com/v1/me")!
        let data = try await get(url: url, token: token)
        do {
            return try JSONDecoder().decode(OpenAIMeResponse.self, from: data)
        } catch {
            logger.error("OpenAI /v1/me parse error")
            throw FetchError.parseError("/v1/me parse error: \(error)")
        }
    }

    // MARK: - Billing API calls (for API key strategy)

    private func fetchSubscription(token: String) async throws -> OpenAISubscription {
        let url = URL(string: "https://api.openai.com/v1/dashboard/billing/subscription")!
        let data = try await get(url: url, token: token)
        do {
            return try JSONDecoder().decode(OpenAISubscription.self, from: data)
        } catch {
            throw FetchError.parseError("Subscription parse error: \(error)")
        }
    }

    private func fetchMonthUsage(token: String) async throws -> OpenAIUsageResponse {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let start = formatter.string(from: startOfMonth)
        let end = formatter.string(from: tomorrow)

        let url = URL(string: "https://api.openai.com/v1/dashboard/billing/usage?start_date=\(start)&end_date=\(end)")!
        let data = try await get(url: url, token: token)
        do {
            return try JSONDecoder().decode(OpenAIUsageResponse.self, from: data)
        } catch {
            logger.error("OpenAI usage parse error", metadata: ["raw": .string(String(data: data, encoding: .utf8) ?? "<binary>")])
            throw FetchError.parseError("Usage parse error: \(error)")
        }
    }

    // MARK: - HTTP

    private func get(url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw FetchError.networkError("Invalid response type")
            }

            switch http.statusCode {
            case 200...299:
                return data
            case 401:
                cachedOAuthToken = nil
                throw FetchError.authExpired
            case 403:
                throw FetchError.authExpired
            case 404:
                logger.warning("OpenAI endpoint returned 404", metadata: ["url": .string(url.absoluteString)])
                throw FetchError.parseError("Endpoint not found: \(url)")
            case 429:
                throw FetchError.rateLimited
            default:
                throw FetchError.networkError("HTTP \(http.statusCode)")
            }
        } catch let error as FetchError {
            throw error
        } catch {
            throw FetchError.networkError(error.localizedDescription)
        }
    }
}
