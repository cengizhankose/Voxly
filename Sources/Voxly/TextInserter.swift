import AppKit
import Carbon.HIToolbox
import os

private let log = Logger(subsystem: "com.voxly.app", category: "TextInserter")

final class TextInserter {
    /// App that was frontmost when the most recent dictation started.
    private(set) var targetApp: NSRunningApplication?

    /// Last external (non-Voxly) app to come forward, tracked continuously via
    /// `NSWorkspace.didActivateApplicationNotification`. Used for paste-from-history
    /// re-paste where the recording-start capture isn't applicable.
    private(set) var lastExternalApp: NSRunningApplication?

    private var activationObserver: NSObjectProtocol?

    init() {
        startTrackingFrontmostApp()
    }

    deinit {
        if let token = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    private func startTrackingFrontmostApp() {
        // Seed with current frontmost if it's not us.
        if let current = NSWorkspace.shared.frontmostApplication,
           current.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastExternalApp = current
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.bundleIdentifier == Bundle.main.bundleIdentifier { return }
            self?.lastExternalApp = app
        }
    }

    /// Called at the start of a recording. Captures the focused app so paste
    /// can return to it even if the menu bar popover steals focus mid-flight.
    func captureFrontmostApp() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier == Bundle.main.bundleIdentifier {
            // Fall back to continuously-tracked last external app.
            targetApp = lastExternalApp
            log.info("Frontmost is Voxly; falling back to lastExternalApp: \(self.targetApp?.localizedName ?? "nil", privacy: .public)")
            return
        }
        targetApp = front
        log.info("Captured target app: \(front?.localizedName ?? "nil", privacy: .public) (\(front?.bundleIdentifier ?? "nil", privacy: .public))")
    }

    /// Paste-from-history convenience: use the last-known external app instead
    /// of the dictation-start capture.
    func insertTextIntoLastExternalApp(_ text: String) -> Bool {
        guard let app = lastExternalApp else {
            log.warning("No external app on record; falling back to clipboard only")
            copyToClipboard(text)
            return false
        }
        targetApp = app
        insertText(text)
        return true
    }

    func insertText(_ text: String) {
        let pasteboard = NSPasteboard.general

        let previousContents = pasteboard.pasteboardItems?.compactMap { item -> (String, Data)? in
            guard let type = item.types.first,
                  let data = item.data(forType: type) else { return nil }
            return (type.rawValue, data)
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        log.info("Pasteboard set, length: \(text.count)")

        reactivateTargetThenPaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let previous = previousContents, !previous.isEmpty {
                    pasteboard.clearContents()
                    for (typeRaw, data) in previous {
                        let type = NSPasteboard.PasteboardType(typeRaw)
                        pasteboard.setData(data, forType: type)
                    }
                }
            }
        }
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func reactivateTargetThenPaste(completion: @escaping () -> Void) {
        let front = NSWorkspace.shared.frontmostApplication
        let needsReactivate = (front?.bundleIdentifier == Bundle.main.bundleIdentifier) && targetApp != nil

        if needsReactivate, let target = targetApp {
            log.info("Reactivating target before paste: \(target.localizedName ?? "?", privacy: .public)")
            target.activate(options: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.simulatePaste()
                completion()
            }
        } else {
            log.info("No reactivation needed (frontmost: \(front?.localizedName ?? "nil", privacy: .public))")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.simulatePaste()
                completion()
            }
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        log.info("Posted Cmd+V")
    }
}
