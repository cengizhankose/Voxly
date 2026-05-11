import AppKit
import Carbon.HIToolbox
import os

private let log = Logger(subsystem: "com.voxly.app", category: "TextInserter")

final class TextInserter {
    /// App that was frontmost before Voxly took focus (e.g. menu bar popover).
    /// Captured at recording start so we can paste back into the right window.
    private(set) var targetApp: NSRunningApplication?

    func captureFrontmostApp() {
        let front = NSWorkspace.shared.frontmostApplication
        // Don't capture ourselves — happens if user fires hotkey while popover open.
        if front?.bundleIdentifier == Bundle.main.bundleIdentifier {
            log.info("Frontmost is Voxly itself; keeping previous target: \(self.targetApp?.localizedName ?? "nil", privacy: .public)")
            return
        }
        targetApp = front
        log.info("Captured target app: \(front?.localizedName ?? "nil", privacy: .public) (\(front?.bundleIdentifier ?? "nil", privacy: .public))")
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
            // Restore previous pasteboard contents after paste settles.
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
            // Wait for activation to settle before posting Cmd+V.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.simulatePaste()
                completion()
            }
        } else {
            log.info("No reactivation needed (frontmost: \(front?.localizedName ?? "nil", privacy: .public))")
            // Small delay so pasteboard write settles before paste.
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
