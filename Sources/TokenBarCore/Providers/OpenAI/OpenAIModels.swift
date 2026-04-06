import Foundation

struct OpenAISubscription: Codable {
    let plan: OpenAIPlan
    let hardLimitUSD: Double
    let softLimitUSD: Double

    enum CodingKeys: String, CodingKey {
        case plan
        case hardLimitUSD = "hard_limit_usd"
        case softLimitUSD = "soft_limit_usd"
    }
}

struct OpenAIPlan: Codable {
    let title: String
}

struct OpenAIUsageResponse: Codable {
    let totalUsage: Double      // in cents
    let dailyCosts: [OpenAIDailyCost]?

    enum CodingKeys: String, CodingKey {
        case totalUsage = "total_usage"
        case dailyCosts = "daily_costs"
    }
}

struct OpenAIDailyCost: Codable {
    let timestamp: Double
    let lineItems: [OpenAILineItem]

    enum CodingKeys: String, CodingKey {
        case timestamp
        case lineItems = "line_items"
    }
}

struct OpenAILineItem: Codable {
    let name: String
    let cost: Double
}

// MARK: - /v1/me response (OAuth path)

struct OpenAIMeResponse: Codable {
    let id: String
    let email: String?
    let name: String?
    let chatgptPlanType: String?

    enum OuterKeys: String, CodingKey {
        case id, email, name, orgs
    }

    enum OrgsKeys: String, CodingKey {
        case data
    }

    // The plan type is nested deep in the JWT claims embedded in the response
    // but also available at the top level in some responses.
    // We parse it from the "orgs" or fall back to nil.
    init(from decoder: Decoder) throws {
        // First try flat structure
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.chatgptPlanType = try container.decodeIfPresent(String.self, forKey: .chatgptPlanType)
    }

    enum CodingKeys: String, CodingKey {
        case id, email, name
        case chatgptPlanType = "chatgpt_plan_type"
    }
}
