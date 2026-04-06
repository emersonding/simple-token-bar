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
        let hostingController = NSHostingController(
            rootView: PopoverContentView(pollingService: pollingService)
        )
        // Let SwiftUI drive the size — don't constrain with fixed contentSize
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
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
