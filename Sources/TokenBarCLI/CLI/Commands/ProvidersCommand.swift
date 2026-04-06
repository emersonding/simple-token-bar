import ArgumentParser
import TokenBarCore

struct ProvidersCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "providers",
        abstract: "List configured providers and their status"
    )

    func run() async throws {
        for id in ProviderID.allCases {
            let enabled = ProviderRegistry.shared.isEnabled(id)
            let status: String
            switch id {
            case .claude:
                let cookieAvailable = (try? await BrowserCookieManager.shared.cookie(named: "sessionKey", domain: "claude.ai")) != nil
                status = cookieAvailable ? "configured (cookie)" : "not configured"
            case .openai:
                let keyAvailable = await KeychainManager.shared.exists(key: "openai.apiKey")
                status = keyAvailable ? "configured (api key)" : "not configured"
            }
            let enabledStr = enabled ? "" : " [disabled]"
            print("\(id.rawValue): \(status)\(enabledStr)")
        }
    }
}
