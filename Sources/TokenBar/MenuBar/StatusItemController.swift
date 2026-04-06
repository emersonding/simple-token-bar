import AppKit
import TokenBarCore

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private var popoverController: PopoverController?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = StatusIconRenderer.renderIcon(usedPercent: nil)
            button.imagePosition = .imageLeft
            button.action = #selector(handleClick)
            button.target = self
            button.setAccessibilityTitle("TokenBar Usage")
        }
    }

    func configure(pollingService: UsagePollingService) {
        popoverController = PopoverController(pollingService: pollingService)
    }

    func updateDisplay(snapshots: [ProviderID: Result<UsageSnapshot, FetchError>]) {
        // Show Claude usage by default; fall back to highest across providers
        let claudeUsed: Double? = {
            guard case .success(let s) = snapshots[.claude] else { return nil }
            return s.primary?.usedPercent ?? s.secondary?.usedPercent
        }()
        let maxUsed = claudeUsed ?? snapshots.values.compactMap { result -> Double? in
            guard case .success(let snapshot) = result else { return nil }
            return snapshot.primary?.usedPercent ?? snapshot.secondary?.usedPercent
        }.max()

        if let button = statusItem.button {
            button.image = StatusIconRenderer.renderIcon(usedPercent: maxUsed)
            if let pct = maxUsed {
                button.title = " \(Int(pct))%"
                button.setAccessibilityTitle("TokenBar: \(Int(pct))% used")
            } else {
                button.title = ""
                button.setAccessibilityTitle("TokenBar Usage")
            }
        }
    }

    @objc private func handleClick() {
        guard let button = statusItem.button else { return }
        popoverController?.show(relativeTo: button)
    }
}
