import SwiftUI

@main
struct TokenBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — menu bar only. Settings are inline in the popover.
        Settings { EmptyView() }
    }
}
