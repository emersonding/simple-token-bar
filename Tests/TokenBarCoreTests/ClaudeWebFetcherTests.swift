#if os(macOS)
import XCTest
@testable import TokenBarCore

final class ClaudeWebFetcherTests: XCTestCase {

    private var mockSession: URLSession!
    private var cookieManager: BrowserCookieManager!

    // Fixture: a single org returned by /api/organizations
    private static let orgListData = """
    [{"uuid":"org-test123","name":"Test Org"}]
    """.data(using: .utf8)!

    // Fixture: 5h + 7d usage windows (from task spec)
    private static let usageData = """
    {
      "five_hour": {"utilization": 42.5, "resets_at": "2026-04-06T18:00:00Z"},
      "seven_day": {"utilization": 15.0, "resets_at": "2026-04-10T00:00:00Z"}
    }
    """.data(using: .utf8)!

    override func setUp() async throws {
        mockSession = MockURLProtocol.makeSession()
        // All browsers disabled — cookie only served from seeded cache
        cookieManager = BrowserCookieManager(
            config: CookieConfig(enableChrome: false, enableSafari: false, enableFirefox: false)
        )
        await cookieManager.seedCookieForTesting(
            name: "sessionKey", domain: "claude.ai", value: "test-session-key"
        )
        MockURLProtocol.requestHandler = nil
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
    }

    // MARK: - Happy path

    func testFetchUsageReturnsPrimaryAnd7dWindows() async throws {
        let orgListData = Self.orgListData
        let usageData = Self.usageData

        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            let url = request.url!
            if path == "/api/organizations" {
                return (MockURLProtocol.response(url: url, statusCode: 200), orgListData)
            } else if path.hasSuffix("/usage") {
                return (MockURLProtocol.response(url: url, statusCode: 200), usageData)
            } else {
                // overage_spend_limit — return 404; fetcher uses try? so this is handled gracefully
                return (MockURLProtocol.response(url: url, statusCode: 404), Data())
            }
        }

        let fetcher = ClaudeWebFetcher(cookieManager: cookieManager, session: mockSession)
        let snapshot = try await fetcher.fetchUsage()

        XCTAssertEqual(snapshot.providerID, .claude)

        // 5-hour window
        let primary = try XCTUnwrap(snapshot.primary)
        XCTAssertEqual(primary.usedPercent, 42.5, accuracy: 0.001)
        XCTAssertEqual(primary.windowMinutes, 300)

        // 7-day window
        let secondary = try XCTUnwrap(snapshot.secondary)
        XCTAssertEqual(secondary.usedPercent, 15.0, accuracy: 0.001)
        XCTAssertEqual(secondary.windowMinutes, 7 * 24 * 60)

        // resetsAt parsed from ISO8601
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let expectedReset = iso.date(from: "2026-04-06T18:00:00Z")!
        let resetsAt = try XCTUnwrap(primary.resetsAt)
        XCTAssertEqual(resetsAt.timeIntervalSince1970, expectedReset.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - Error cases

    func testFetchUsageThrowsAuthExpiredOn401() async throws {
        MockURLProtocol.requestHandler = { request in
            (MockURLProtocol.response(url: request.url!, statusCode: 401), Data())
        }

        let fetcher = ClaudeWebFetcher(cookieManager: cookieManager, session: mockSession)
        do {
            _ = try await fetcher.fetchUsage()
            XCTFail("Expected FetchError.authExpired to be thrown")
        } catch FetchError.authExpired {
            // expected
        } catch {
            XCTFail("Expected FetchError.authExpired but got \(error)")
        }
    }

    func testFetchUsageThrowsParseErrorOnMalformedUsageJSON() async throws {
        let orgListData = Self.orgListData

        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            let url = request.url!
            if path == "/api/organizations" {
                return (MockURLProtocol.response(url: url, statusCode: 200), orgListData)
            } else {
                let bad = "not-valid-json".data(using: .utf8)!
                return (MockURLProtocol.response(url: url, statusCode: 200), bad)
            }
        }

        let fetcher = ClaudeWebFetcher(cookieManager: cookieManager, session: mockSession)
        do {
            _ = try await fetcher.fetchUsage()
            XCTFail("Expected FetchError.parseError to be thrown")
        } catch FetchError.parseError {
            // expected
        } catch {
            XCTFail("Expected FetchError.parseError but got \(error)")
        }
    }

    func testFetchUsageThrowsNotConfiguredWhenCookieMissing() async throws {
        // New manager with no browsers enabled and no seeded cookie → returns nil
        let noCookieManager = BrowserCookieManager(
            config: CookieConfig(enableChrome: false, enableSafari: false, enableFirefox: false)
        )
        let fetcher = ClaudeWebFetcher(cookieManager: noCookieManager, session: mockSession)
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
#endif
