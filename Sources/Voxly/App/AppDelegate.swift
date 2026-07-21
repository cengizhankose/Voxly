import AppKit
import os

private let log = Logger(subsystem: "com.voxly.app", category: "AppDelegate")

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Voxly keeps living in the menu bar after its main window is closed.
        // The user terminates the app explicitly via Quit menu item or ⌘Q.
        false
    }

    /// Explicit and unconditional so Quit always works: without this, SwiftUI's
    /// adaptor delegate owns the decision and has been observed deferring
    /// termination requested from the menu-bar popover.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        log.notice("applicationShouldTerminate -> terminateNow")
        return .terminateNow
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("Application finished launching")
        closeMainWindowIfSuppressed(retriesLeft: 20)
    }

    /// SwiftUI always presents the `Window("Voxly", id: "main")` scene at
    /// launch; `.defaultLaunchBehavior(.suppressed)` requires macOS 15 while
    /// the app targets 13, so the window is closed here instead. The window
    /// may not exist yet when this fires, hence the short retry loop.
    /// Onboarding is exempt — its sheet needs the window as a host.
    private func closeMainWindowIfSuppressed(retriesLeft: Int) {
        // Keys mirror SettingsStore.Key; the store itself lives on AppState,
        // which the delegate has no reference to.
        let defaults = UserDefaults.standard
        let showOnLaunch = defaults.object(forKey: "showWindowOnLaunch") as? Bool ?? true
        let onboarded = defaults.bool(forKey: "hasCompletedOnboarding")
        guard !showOnLaunch, onboarded else { return }

        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") == true }) {
            log.info("Closing main window at launch (showWindowOnLaunch=false)")
            window.close()
            return
        }
        guard retriesLeft > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.closeMainWindowIfSuppressed(retriesLeft: retriesLeft - 1)
        }
    }
}
