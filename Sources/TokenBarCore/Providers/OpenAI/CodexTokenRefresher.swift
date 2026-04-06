import Foundation
import Logging

private let logger = Logger(label: "com.tokenbar.codex-token-refresh")

/// Refreshes Codex OAuth tokens via OpenAI's auth endpoint.
struct CodexTokenRefresher: Sendable {
    private static let tokenEndpoint = URL(string: "https://auth.openai.com/oauth/token")!
    private static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"

    /// Refreshes the access token using the refresh token.
    /// Returns the new access token, or nil on failure.
    static func refresh(refreshToken: String, session: URLSession = .shared) async -> String? {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": clientID,
            "refresh_token": refreshToken,
            "scope": "openai profile email",
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                logger.warning("Token refresh failed with status \(status)")
                return nil
            }

            let result = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
            logger.info("Codex OAuth token refreshed successfully")
            return result.accessToken
        } catch {
            logger.warning("Token refresh error: \(error)")
            return nil
        }
    }
}

private struct TokenRefreshResponse: Codable {
    let accessToken: String
    let tokenType: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}
