import Foundation
import Logging

private let logger = Logger(label: "com.tokenbar.codex-oauth")

/// Reads and manages OAuth credentials from ~/.codex/auth.json
/// (auto-created by the Codex CLI on login).
struct CodexOAuthCredentials: Sendable {
    let accessToken: String
    let refreshToken: String
    let idToken: String?
    let accountId: String?
    let lastRefresh: Date?

    /// Reads credentials from the default path (~/.codex/auth.json or $CODEX_HOME/auth.json).
    static func load() -> CodexOAuthCredentials? {
        let path: String
        if let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"] {
            path = (codexHome as NSString).appendingPathComponent("auth.json")
        } else {
            path = (NSHomeDirectory() as NSString).appendingPathComponent(".codex/auth.json")
        }

        guard FileManager.default.fileExists(atPath: path) else {
            logger.debug("No codex auth.json found at \(path)")
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let raw = try JSONDecoder().decode(RawAuthFile.self, from: data)

            guard let tokens = raw.tokens,
                  let accessToken = tokens.accessToken,
                  let refreshToken = tokens.refreshToken else {
                logger.warning("codex auth.json missing tokens")
                return nil
            }

            var lastRefresh: Date?
            if let dateStr = raw.lastRefresh {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                lastRefresh = formatter.date(from: dateStr)
            }

            return CodexOAuthCredentials(
                accessToken: accessToken,
                refreshToken: refreshToken,
                idToken: tokens.idToken,
                accountId: tokens.accountId,
                lastRefresh: lastRefresh
            )
        } catch {
            logger.warning("Failed to parse codex auth.json: \(error)")
            return nil
        }
    }

    /// Whether the token needs refresh (older than 8 days or no lastRefresh).
    var needsRefresh: Bool {
        guard let lastRefresh else { return true }
        let eightDays: TimeInterval = 8 * 24 * 60 * 60
        return Date().timeIntervalSince(lastRefresh) > eightDays
    }
}

// MARK: - Raw JSON structure matching ~/.codex/auth.json

private struct RawAuthFile: Codable {
    let authMode: String?
    let tokens: RawTokens?
    let lastRefresh: String?

    enum CodingKeys: String, CodingKey {
        case authMode = "auth_mode"
        case tokens
        case lastRefresh = "last_refresh"
    }
}

private struct RawTokens: Codable {
    let accessToken: String?
    let refreshToken: String?
    let idToken: String?
    let accountId: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case accountId = "account_id"
    }
}
