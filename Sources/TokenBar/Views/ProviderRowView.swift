import SwiftUI
import TokenBarCore

struct ProviderRowView: View {
    let providerID: ProviderID
    let result: Result<UsageSnapshot, FetchError>

    private var icon: String {
        switch providerID {
        case .claude: return "c.circle"
        case .openai: return "sparkles"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(providerID.displayName)
                    .font(.headline)
                Spacer()
            }

            switch result {
            case .success(let snapshot):
                if let primary = snapshot.primary {
                    SessionMeterView(window: primary, label: windowLabel(for: primary))
                }
                if let secondary = snapshot.secondary {
                    WeeklyMeterView(window: secondary)
                }
                if let credits = snapshot.credits {
                    Text(String(format: "%@ %.2f remaining", credits.currency, credits.remaining))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Show account info when connected but no usage meters
                if snapshot.primary == nil, snapshot.secondary == nil, snapshot.credits == nil,
                   let identity = snapshot.identity {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            if let email = identity.accountEmail {
                                Text(email).font(.caption)
                            }
                            if let org = identity.organization {
                                Text(org).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

            case .failure(let error):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(errorMessage(for: error))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func windowLabel(for window: RateWindow) -> String {
        if let minutes = window.windowMinutes {
            let hours = minutes / 60
            return hours > 0 ? "Session (\(hours)h)" : "Session (\(minutes)m)"
        }
        return "Session"
    }

    private func errorMessage(for error: FetchError) -> String {
        switch error {
        case .notConfigured:
            switch providerID {
            case .claude: return "Not configured — login to claude.ai in Chrome"
            case .openai: return "Not configured — run `codex` to login, or add API key in Settings"
            }
        case .authExpired:              return "Session expired — re-login in browser"
        case .rateLimited:              return "Rate limited — try again later"
        case .networkError(let detail): return "Network error: \(detail)"
        case .parseError(let detail):   return "Parse error: \(detail)"
        }
    }
}
