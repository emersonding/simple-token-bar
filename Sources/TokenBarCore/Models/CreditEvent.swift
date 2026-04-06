import Foundation

public struct CreditEvent: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let service: String
    public let creditsUsed: Double

    public init(id: UUID = UUID(), date: Date, service: String, creditsUsed: Double) {
        self.id = id
        self.date = date
        self.service = service
        self.creditsUsed = creditsUsed
    }
}
