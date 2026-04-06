import SwiftUI
import TokenBarCore

struct WeeklyMeterView: View {
    let window: RateWindow

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
                Text("Weekly")
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
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    Text(countdownText(resetsAt: resetsAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func countdownText(resetsAt: Date) -> String {
        let remaining = resetsAt.timeIntervalSinceNow
        guard remaining > 0 else { return "Resetting…" }
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        if days > 0 {
            return "Resets in \(days)d \(hours)h"
        } else {
            let minutes = (Int(remaining) % 3600) / 60
            return "Resets in \(hours)h \(minutes)m"
        }
    }
}
