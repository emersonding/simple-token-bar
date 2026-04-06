import Foundation

public final class ProviderRegistry: @unchecked Sendable {
    public static let shared = ProviderRegistry()

    private let lock = NSLock()
    private var enabledSet: Set<ProviderID> = [.claude, .openai]

    private init() {}

    public func enabledProviders() -> [any UsageProviding] {
        var providers: [any UsageProviding] = []
        #if os(macOS)
        if isEnabled(.claude) {
            providers.append(ClaudeWebFetcher.shared)
        }
        #endif
        if isEnabled(.openai) {
            providers.append(OpenAIAPIFetcher.shared)
        }
        return providers
    }

    public func fetchAll() async -> [ProviderID: Result<UsageSnapshot, FetchError>] {
        let providers = enabledProviders()
        var results: [ProviderID: Result<UsageSnapshot, FetchError>] = [:]

        await withTaskGroup(of: (ProviderID, Result<UsageSnapshot, FetchError>).self) { group in
            for provider in providers {
                group.addTask {
                    let id = await provider.providerID
                    do {
                        let snapshot = try await withTimeout(seconds: 20) {
                            try await provider.fetchUsage()
                        }
                        return (id, .success(snapshot))
                    } catch let error as FetchError {
                        return (id, .failure(error))
                    } catch {
                        return (id, .failure(.networkError(error.localizedDescription)))
                    }
                }
            }

            for await (id, result) in group {
                results[id] = result
            }
        }

        return results
    }

    public func setEnabled(_ providerID: ProviderID, enabled: Bool) {
        lock.withLock {
            if enabled {
                enabledSet.insert(providerID)
            } else {
                enabledSet.remove(providerID)
            }
        }
    }

    public func isEnabled(_ providerID: ProviderID) -> Bool {
        lock.withLock { enabledSet.contains(providerID) }
    }
}

// Helper: run an async operation with a timeout, cancelling the loser.
private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw FetchError.networkError("Request timed out after \(Int(seconds))s")
        }
        guard let result = try await group.next() else {
            throw CancellationError()
        }
        group.cancelAll()
        return result
    }
}
