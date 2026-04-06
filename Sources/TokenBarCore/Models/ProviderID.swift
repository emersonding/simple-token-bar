public enum ProviderID: String, Codable, CaseIterable, Sendable, Hashable {
    case claude
    case openai

    public var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "OpenAI"
        }
    }
}
