import ArgumentParser
import Foundation
import TokenBarCore

struct HistoryCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "history",
        abstract: "Show historical usage snapshots"
    )

    @Option(name: .long, help: "Filter by provider (claude, openai)")
    var provider: String? = nil

    @Option(name: .long, help: "Number of days to show")
    var days: Int = 7

    func run() async throws {
        // History store not yet implemented — placeholder output
        print("History: last \(days) day(s)")
        if let p = provider {
            print("Provider: \(p)")
        }
        print("(History store coming in a future release)")
    }
}
