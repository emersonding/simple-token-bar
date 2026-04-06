import Foundation

public struct CreditsSnapshot: Codable, Equatable, Sendable {
    public let remaining: Double
    public let currency: String
    public let events: [CreditEvent]
    public let updatedAt: Date

    public init(remaining: Double, currency: String, events: [CreditEvent] = [], updatedAt: Date = Date()) {
        self.remaining = remaining
        self.currency = currency
        self.events = events
        self.updatedAt = updatedAt
    }
}
