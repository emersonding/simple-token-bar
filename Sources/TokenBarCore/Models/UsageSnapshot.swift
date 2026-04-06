import Foundation

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let providerID: ProviderID
    public let primary: RateWindow?
    public let secondary: RateWindow?
    public let credits: CreditsSnapshot?
    public let updatedAt: Date
    public let identity: ProviderIdentity?

    public init(
        providerID: ProviderID,
        primary: RateWindow? = nil,
        secondary: RateWindow? = nil,
        credits: CreditsSnapshot? = nil,
        updatedAt: Date = Date(),
        identity: ProviderIdentity? = nil
    ) {
        self.providerID = providerID
        self.primary = primary
        self.secondary = secondary
        self.credits = credits
        self.updatedAt = updatedAt
        self.identity = identity
    }
}
