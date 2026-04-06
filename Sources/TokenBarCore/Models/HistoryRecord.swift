import Foundation

public struct HistoryRecord: Codable, Sendable {
    public let id: UUID
    public let snapshot: UsageSnapshot
    public let recordedAt: Date

    /// Derived from the contained snapshot — not stored separately.
    public var providerID: ProviderID { snapshot.providerID }

    public init(id: UUID = UUID(), snapshot: UsageSnapshot, recordedAt: Date = Date()) {
        self.id = id
        self.snapshot = snapshot
        self.recordedAt = recordedAt
    }
}
