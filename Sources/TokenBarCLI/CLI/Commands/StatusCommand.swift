import ArgumentParser
import Foundation
import TokenBarCore

struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show current token usage for all providers"
    )

    @Option(name: .long, help: "Filter by provider (claude, openai)")
    var provider: String? = nil

    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false

    func run() async throws {
        let results = await ProviderRegistry.shared.fetchAll()

        let filtered: [ProviderID: Result<UsageSnapshot, FetchError>]
        if let providerStr = provider {
            guard let id = ProviderID(rawValue: providerStr) else {
                throw ValidationError("Unknown provider '\(providerStr)'. Valid values: \(ProviderID.allCases.map(\.rawValue).joined(separator: ", "))")
            }
            filtered = results.filter { $0.key == id }
        } else {
            filtered = results
        }

        let allFailed = !filtered.isEmpty && filtered.values.allSatisfy { if case .failure = $0 { return true } else { return false } }

        if json {
            printJSON(filtered)
        } else {
            printTable(filtered)
        }

        if allFailed {
            fputs("Error: all providers failed to fetch usage.\n", stderr)
            throw ExitCode.failure
        }
    }

    private func printJSON(_ results: [ProviderID: Result<UsageSnapshot, FetchError>]) {
        var output: [[String: Any]] = []
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        for (id, result) in results.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            switch result {
            case .success(let snapshot):
                var entry: [String: Any] = [
                    "provider": id.rawValue,
                    "updated_at": formatter.string(from: snapshot.updatedAt),
                ]
                if let primary = snapshot.primary {
                    var w: [String: Any] = ["used_percent": primary.usedPercent]
                    if let minutes = primary.windowMinutes { w["window_minutes"] = minutes }
                    if let resets = primary.resetsAt { w["resets_at"] = formatter.string(from: resets) }
                    entry["session"] = w
                }
                if let secondary = snapshot.secondary {
                    var w: [String: Any] = ["used_percent": secondary.usedPercent]
                    if let resets = secondary.resetsAt { w["resets_at"] = formatter.string(from: resets) }
                    entry["weekly"] = w
                }
                if let credits = snapshot.credits {
                    entry["credits"] = ["remaining": credits.remaining, "currency": credits.currency]
                }
                output.append(entry)
            case .failure(let error):
                output.append(["provider": id.rawValue, "error": "\(error)"])
            }
        }

        if let data = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    private func printTable(_ results: [ProviderID: Result<UsageSnapshot, FetchError>]) {
        for (id, result) in results.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            print("[\(id.displayName)]")
            switch result {
            case .success(let snapshot):
                if let p = snapshot.primary {
                    print("  Session:  \(Int(p.usedPercent))% used")
                }
                if let s = snapshot.secondary {
                    print("  Weekly:   \(Int(s.usedPercent))% used")
                }
                if let c = snapshot.credits {
                    print(String(format: "  Credits:  %.2f %@ remaining", c.remaining, c.currency))
                }
            case .failure(let error):
                print("  Error: \(error)")
            }
        }
    }
}
