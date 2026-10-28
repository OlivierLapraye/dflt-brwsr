import AppKit
import AppIntents

// A background-only app bundle is required for macOS to discover App Intents.
// It deliberately has no window, menu bar item, or Dock icon.
@main
enum DefaultBrowserApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        BrowserShortcuts.updateAppShortcutParameters()
    }
}
