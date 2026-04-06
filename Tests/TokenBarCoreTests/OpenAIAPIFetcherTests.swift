import XCTest
@testable import TokenBarCore

final class OpenAIAPIFetcherTests: XCTestCase {

    private var mockSession: URLSession!
    private var keychainManager: KeychainManager!

    // Fixture: subscription with $100 hard limit
    private static let subscriptionData = """
    {"plan":{"title":"Pay as you go"},"hard_limit_usd":100.0,"soft_limit_usd":80.0}
    """.data(using: .utf8)!

    // Fixture: 500 cents ($5.00) of usage this month
    private static let usageData = """
    {"total_usage":500.0,"daily_costs":null}
    """.data(using: .utf8)!

    override func setUp() async throws {
        mockSession = MockURLProtocol.makeSession()
        // Isolated service name prevents touching production keychain data
        keychainManager = KeychainManager(service: "com.tokenbar.tests")
        try await keychainManager.delete(key: "openai.apiKey")
        MockURLProtocol.requestHandler = nil
    }

    override func tearDown() async throws {
        MockURLProtocol.requestHandler = nil
        try? await keychainManager.delete(key: "openai.apiKey")
    }

    // MARK: - Happy path

    func testFetchUsageReturnsCorrectCreditsAndUsagePercent() async throws {
        try await keychainManager.save(key: "openai.apiKey", value: "sk-test-key")

        let subscriptionData = Self.subscriptionData
        let usageData = Self.usageData

        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            let url = request.url!
            if path == "/v1/dashboard/billing/subscription" {
                return (MockURLProtocol.response(url: url, statusCode: 200), subscriptionData)
            } else if path == "/v1/dashboard/billing/usage" {
                return (MockURLProtocol.response(url: url, statusCode: 200), usageData)
            }
            throw URLError(.badURL)
        }

        let fetcher = OpenAIAPIFetcher(keychainManager: keychainManager, session: mockSession)
        let snapshot = try await fetcher.fetchUsage()

        XCTAssertEqual(snapshot.providerID, .openai)
        // total_usage 500 cents = $5.00; hard_limit $100; remaining = $95
        let remaining = try XCTUnwrap(snapshot.credits?.remaining)
        XCTAssertEqual(remaining, 95.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.credits?.currency, "USD")
        // usedPercent = 5.0 / 100.0 * 100 = 5.0
        let usedPercent = try XCTUnwrap(snapshot.primary?.usedPercent)
        XCTAssertEqual(usedPercent, 5.0, accuracy: 0.001)
    }

    // MARK: - Error cases

    func testFetchUsageThrowsAuthExpiredOn401() async throws {
        try await keychainManager.save(key: "openai.apiKey", value: "sk-test-key")

        MockURLProtocol.requestHandler = { request in
            (MockURLProtocol.response(url: request.url!, statusCode: 401), Data())
        }

        let fetcher = OpenAIAPIFetcher(keychainManager: keychainManager, session: mockSession)
        do {
            _ = try await fetcher.fetchUsage()
            XCTFail("Expected FetchError.authExpired to be thrown")
        } catch FetchError.authExpired {
            // expected
        } catch {
            XCTFail("Expected FetchError.authExpired but got \(error)")
        }
    }

    func testFetchUsageThrowsNotConfiguredWhenNoAPIKey() async throws {
        // No key saved — keychainManager has a clean slate from setUp
        let fetcher = OpenAIAPIFetcher(keychainManager: keychainManager, session: mockSession)
        do {
            _ = try await fetcher.fetchUsage()
            XCTFail("Expected FetchError.notConfigured to be thrown")
        } catch FetchError.notConfigured {
            // expected
        } catch {
            XCTFail("Expected FetchError.notConfigured but got \(error)")
        }
    }
}
