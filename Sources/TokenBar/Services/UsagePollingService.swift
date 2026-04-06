import Foundation
import Observation
import TokenBarCore

@MainActor
@Observable
final class UsagePollingService {
    var snapshots: [ProviderID: Result<UsageSnapshot, FetchError>] = [:]
    var lastUpdated: Date? = nil
    var isRefreshing: Bool = false

    enum RefreshInterval: Int, CaseIterable {
        case manual = 0
        case oneMinute = 60
        case twoMinutes = 120
        case fiveMinutes = 300
        case fifteenMinutes = 900

        var displayName: String {
            switch self {
            case .manual:         return "Manual"
            case .oneMinute:      return "1 Minute"
            case .twoMinutes:     return "2 Minutes"
            case .fiveMinutes:    return "5 Minutes"
            case .fifteenMinutes: return "15 Minutes"
            }
        }
    }

    var interval: RefreshInterval = .fiveMinutes {
        didSet {
            defaults.set(interval.rawValue, forKey: "refreshInterval")
            if pollingTask != nil {
                stopPolling()
                startPolling()
            }
        }
    }

    private var pollingTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private let defaults = UserDefaults(suiteName: "com.tokenbar")!

    init() {
        let stored = defaults.integer(forKey: "refreshInterval")
        interval = RefreshInterval(rawValue: stored) ?? .fiveMinutes
    }

    func startPolling() {
        guard interval != .manual else { return }
        stopPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                // Exit loop when service is deallocated
                guard let self else { break }
                await self.performFetch()
                let seconds = self.interval.rawValue
                guard seconds > 0 else { break }
                try? await Task.sleep(for: .seconds(seconds))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refreshNow() async {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.performFetch()
        }
        await refreshTask?.value
        // Reset polling timer
        if pollingTask != nil {
            stopPolling()
            startPolling()
        }
    }

    private func performFetch() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let results = await ProviderRegistry.shared.fetchAll()
        snapshots = results
        lastUpdated = Date()
    }
}
