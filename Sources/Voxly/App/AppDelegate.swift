import AppKit
import os

private let log = Logger(subsystem: "com.voxly.app", category: "AppDelegate")

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Voxly keeps living in the menu bar after its main window is closed.
        // The user terminates the app explicitly via Quit menu item or ⌘Q.
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("Application finished launching")
    }
}
