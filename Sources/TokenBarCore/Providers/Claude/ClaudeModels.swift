import Foundation

struct ClaudeOrganization: Codable {
    let uuid: String
    let name: String
}

struct ClaudeUsageResponse: Codable {
    struct Window: Codable {
        let utilization: Double
        let resetsAt: Date?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    let fiveHour: Window?
    let sevenDay: Window?
    let sevenDayOpus: Window?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
    }
}

struct ClaudeSpendLimitResponse: Codable {
    let monthlyCreditLimit: Double?
    let currency: String
    let usedCredits: Double
    let isEnabled: Bool
}
