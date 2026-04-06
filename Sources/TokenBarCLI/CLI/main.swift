import ArgumentParser

struct TokenBarCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tokenbar",
        abstract: "Query AI provider token usage",
        subcommands: [StatusCommand.self, ProvidersCommand.self, HistoryCommand.self]
    )
}

TokenBarCLI.main()
