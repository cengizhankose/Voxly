import AVFoundation
import AppKit
import os

private let log = Logger(subsystem: "com.voxly.app", category: "PermissionsManager")

final class PermissionsManager {
    func requestMicrophoneAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Non-prompting current state. Used for refresh checks.
    func checkMicrophoneAccessSync() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Removes Voxly's Accessibility entry from TCC.db so a fresh re-grant binds
    /// to the *current* CDHash. Necessary for ad-hoc-signed dev builds where
    /// every rebuild invalidates the prior trust entry.
    /// Returns true on exit code 0.
    @discardableResult
    func resetAccessibility() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/tccutil"
        task.arguments = ["reset", "Accessibility", Bundle.main.bundleIdentifier ?? "com.voxly.app"]
        do {
            try task.run()
            task.waitUntilExit()
            let ok = task.terminationStatus == 0
            log.info("tccutil reset Accessibility -> exit \(task.terminationStatus)")
            return ok
        } catch {
            log.error("tccutil reset failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
