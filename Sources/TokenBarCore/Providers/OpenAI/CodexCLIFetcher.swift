import Foundation
import Logging

private let logger = Logger(label: "com.tokenbar.codex-cli")

/// Fetches Codex usage via the Codex CLI's JSON-RPC interface.
/// Launches `codex app-server` (stdio), sends JSON-RPC `account/rateLimits/read`.
struct CodexCLIFetcher: Sendable {

    /// Attempts to fetch rate limits from the Codex CLI.
    /// Returns nil if codex is not installed or the RPC fails.
    static func fetchRateLimits() async -> CodexRateLimitsResponse? {
        guard let codexPath = findCodex() else {
            logger.debug("codex CLI not found in PATH")
            return nil
        }

        logger.info("Using codex CLI at \(codexPath)")

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let result = runCodexRPC(codexPath: codexPath)
                continuation.resume(returning: result)
            }
        }
    }

    private static func findCodex() -> String? {
        // Check common paths since Process may not inherit full shell PATH
        let candidates = [
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
            "\(NSHomeDirectory())/.nvm/versions/node/v22.18.0/bin/codex",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fallback: try `which`
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "codex"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return path?.isEmpty == false ? path : nil
        } catch {
            return nil
        }
    }

    private static func runCodexRPC(codexPath: String) -> CodexRateLimitsResponse? {
        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: codexPath)
        process.arguments = ["app-server"]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        // Inherit PATH so codex can find node etc.
        var env = ProcessInfo.processInfo.environment
        if env["PATH"] == nil {
            env["PATH"] = "/usr/local/bin:/usr/bin:/bin"
        }
        process.environment = env

        do {
            try process.run()
        } catch {
            logger.warning("Failed to launch codex CLI: \(error)")
            return nil
        }

        defer { process.terminate() }

        let writer = stdinPipe.fileHandleForWriting
        let reader = stdoutPipe.fileHandleForReading

        // 1. Send initialize
        let initMsg = #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"TokenBar","version":"1.0.0"}}}"# + "\n"
        writer.write(initMsg.data(using: .utf8)!)

        guard readLine(from: reader, timeout: 10) != nil else {
            logger.warning("No response to initialize")
            return nil
        }

        // 2. Send account/rateLimits/read
        let rlMsg = #"{"jsonrpc":"2.0","id":2,"method":"account/rateLimits/read","params":{}}"# + "\n"
        writer.write(rlMsg.data(using: .utf8)!)

        guard let responseData = readLine(from: reader, timeout: 10) else {
            logger.warning("No response to account/rateLimits/read")
            return nil
        }

        writer.closeFile()

        // Parse
        do {
            let rpc = try JSONDecoder().decode(RPCResponse<CodexRateLimitsResponse>.self, from: responseData)
            if let result = rpc.result {
                logger.info("Codex rate limits: primary=\(result.rateLimits?.primary?.usedPercent ?? -1)%, secondary=\(result.rateLimits?.secondary?.usedPercent ?? -1)%, plan=\(result.rateLimits?.planType ?? "?")")
                return result
            }
            if let err = rpc.error {
                logger.warning("RPC error: \(err.message)")
            }
            return nil
        } catch {
            logger.warning("Failed to parse rate limits: \(error)")
            return nil
        }
    }

    /// Reads one newline-delimited JSON line from the file handle.
    private static func readLine(from handle: FileHandle, timeout: TimeInterval) -> Data? {
        var buffer = Data()
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let chunk = handle.availableData
            if chunk.isEmpty {
                Thread.sleep(forTimeInterval: 0.05)
                continue
            }
            buffer.append(chunk)
            if let str = String(data: buffer, encoding: .utf8), str.contains("\n") {
                // Return the first complete JSON line
                if let lineEnd = str.firstIndex(of: "\n") {
                    let line = str[str.startIndex..<lineEnd]
                    return Data(line.utf8)
                }
            }
        }
        return nil
    }
}

// MARK: - JSON-RPC envelope

private struct RPCResponse<T: Codable>: Codable {
    let id: Int?
    let result: T?
    let error: RPCError?
}

private struct RPCError: Codable {
    let code: Int
    let message: String
}

// MARK: - Codex rate limits response (matches actual CLI output)

struct CodexRateLimitsResponse: Codable, Sendable {
    let rateLimits: CodexLimitSet?
}

struct CodexLimitSet: Codable, Sendable {
    let limitId: String?
    let primary: CodexWindow?
    let secondary: CodexWindow?
    let credits: CodexCredits?
    let planType: String?
}

struct CodexWindow: Codable, Sendable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Double?       // Unix timestamp

    var resetsAtDate: Date? {
        guard let ts = resetsAt else { return nil }
        return Date(timeIntervalSince1970: ts)
    }
}

struct CodexCredits: Codable, Sendable {
    let hasCredits: Bool?
    let unlimited: Bool?
    let balance: String?
}
