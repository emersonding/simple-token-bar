import AppKit
import TokenBarCore

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private(set) var pollingService: UsagePollingService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let service = UsagePollingService()
        pollingService = service

        let controller = StatusItemController()
        controller.configure(pollingService: service)
        statusItemController = controller

        // Observe snapshot updates and forward to status item
        Task { @MainActor in
            // Initial fetch
            await service.refreshNow()
            controller.updateDisplay(snapshots: service.snapshots)

            // Start polling
            service.startPolling()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollingService?.stopPolling()
    }
}
