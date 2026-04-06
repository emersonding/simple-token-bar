import AppKit
import SwiftUI
import TokenBarCore

@MainActor
final class PopoverController {
    private let popover = NSPopover()
    private var pollingService: UsagePollingService

    init(pollingService: UsagePollingService) {
        self.pollingService = pollingService
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 450)
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(pollingService: pollingService)
        )
    }

    func show(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func close() {
        popover.performClose(nil)
    }
}
