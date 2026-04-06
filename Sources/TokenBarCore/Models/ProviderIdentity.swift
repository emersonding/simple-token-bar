public struct ProviderIdentity: Codable, Equatable, Sendable {
    public let providerID: ProviderID
    public let accountEmail: String?
    public let organization: String?

    public init(providerID: ProviderID, accountEmail: String? = nil, organization: String? = nil) {
        self.providerID = providerID
        self.accountEmail = accountEmail
        self.organization = organization
    }
}
