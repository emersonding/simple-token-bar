import XCTest
@testable import TokenBarCore

final class ModelTests: XCTestCase {

    // MARK: - ProviderID

    func testProviderIDClaudeRawValue() {
        XCTAssertEqual(ProviderID.claude.rawValue, "claude")
    }

    func testProviderIDOpenAIRawValue() {
        XCTAssertEqual(ProviderID.openai.rawValue, "openai")
    }

    func testProviderIDDecodesFromValidRawValue() {
        XCTAssertEqual(ProviderID(rawValue: "claude"), .claude)
        XCTAssertEqual(ProviderID(rawValue: "openai"), .openai)
    }

    func testProviderIDReturnsNilForUnknownRawValue() {
        XCTAssertNil(ProviderID(rawValue: "anthropic"))
    }

    func testProviderIDCodableRoundTrip() throws {
        let encoded = try JSONEncoder().encode(ProviderID.openai)
        let decoded = try JSONDecoder().decode(ProviderID.self, from: encoded)
        XCTAssertEqual(decoded, .openai)
    }

    // MARK: - RateWindow

    func testRateWindowRemainingPercentIsOneHundredMinusUsed() {
        XCTAssertEqual(RateWindow(usedPercent: 42.5).remainingPercent, 57.5, accuracy: 0.001)
    }

    func testRateWindowRemainingPercentClampsToZeroWhenOverHundred() {
        XCTAssertEqual(RateWindow(usedPercent: 120.0).remainingPercent, 0.0)
    }

    func testRateWindowRemainingPercentIsZeroAtFullUsage() {
        XCTAssertEqual(RateWindow(usedPercent: 100.0).remainingPercent, 0.0, accuracy: 0.001)
    }

    func testRateWindowCodableRoundTripWithAllFields() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let window = RateWindow(usedPercent: 42.5, windowMinutes: 300, resetsAt: date)
        let encoded = try JSONEncoder().encode(window)
        let decoded = try JSONDecoder().decode(RateWindow.self, from: encoded)
        XCTAssertEqual(decoded, window)
    }

    func testRateWindowCodableRoundTripWithNilOptionals() throws {
        let window = RateWindow(usedPercent: 75.0, windowMinutes: nil, resetsAt: nil)
        let encoded = try JSONEncoder().encode(window)
        let decoded = try JSONDecoder().decode(RateWindow.self, from: encoded)
        XCTAssertEqual(decoded, window)
    }

    // MARK: - CreditsSnapshot

    func testCreditsSnapshotCodableRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let credits = CreditsSnapshot(remaining: 15.50, currency: "USD", events: [], updatedAt: date)
        let encoded = try JSONEncoder().encode(credits)
        let decoded = try JSONDecoder().decode(CreditsSnapshot.self, from: encoded)
        XCTAssertEqual(decoded.remaining, credits.remaining, accuracy: 0.001)
        XCTAssertEqual(decoded.currency, credits.currency)
        XCTAssertEqual(
            decoded.updatedAt.timeIntervalSince1970,
            credits.updatedAt.timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertTrue(decoded.events.isEmpty)
    }

    // MARK: - UsageSnapshot

    func testUsageSnapshotCodableRoundTripWithWindowsAndCredits() throws {
        let date = Date(timeIntervalSince1970: 1_900_000_000)
        let snapshot = UsageSnapshot(
            providerID: .claude,
            primary: RateWindow(usedPercent: 42.5, windowMinutes: 300),
            secondary: RateWindow(usedPercent: 15.0, windowMinutes: 10080),
            credits: CreditsSnapshot(remaining: 50.0, currency: "USD", updatedAt: date),
            updatedAt: date
        )
        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(UsageSnapshot.self, from: encoded)

        XCTAssertEqual(decoded.providerID, .claude)
        let primary = try XCTUnwrap(decoded.primary)
        XCTAssertEqual(primary.usedPercent, 42.5, accuracy: 0.001)
        XCTAssertEqual(primary.windowMinutes, 300)
        let secondary = try XCTUnwrap(decoded.secondary)
        XCTAssertEqual(secondary.usedPercent, 15.0, accuracy: 0.001)
        XCTAssertEqual(secondary.windowMinutes, 10080)
        let remaining = try XCTUnwrap(decoded.credits?.remaining)
        XCTAssertEqual(remaining, 50.0, accuracy: 0.001)
    }

    func testUsageSnapshotCodableRoundTripWithAllNilOptionals() throws {
        let date = Date(timeIntervalSince1970: 2_000_000_000)
        let snapshot = UsageSnapshot(providerID: .openai, updatedAt: date)
        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(UsageSnapshot.self, from: encoded)

        XCTAssertEqual(decoded.providerID, .openai)
        XCTAssertNil(decoded.primary)
        XCTAssertNil(decoded.secondary)
        XCTAssertNil(decoded.credits)
        XCTAssertNil(decoded.identity)
    }
}
