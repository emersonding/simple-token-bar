import SwiftUI
import TokenBarCore

struct SessionMeterView: View {
    let window: RateWindow
    let label: String

    private var color: Color {
        switch window.usedPercent {
        case ..<50: return .green
        case ..<80: return .yellow
        default:    return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(window.usedPercent))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: window.usedPercent / 100)
                .tint(color)
            if let resetsAt = window.resetsAt {
                ResetCountdownView(resetsAt: resetsAt)
            }
        }
    }
}

private struct ResetCountdownView: View {
    let resetsAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            Text(countdownText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var countdownText: String {
        let remaining = resetsAt.timeIntervalSinceNow
        guard remaining > 0 else { return "Resetting…" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }
}
