import Foundation
import Combine
import ServiceManagement
import os

private let log = Logger(subsystem: "com.voxly.app", category: "SettingsStore")

/// Typed wrapper over UserDefaults. Properties are `@Published`; mutations are
/// persisted in `didSet`. Combine subscribers can observe `$selectedModelSize`
/// etc. to react (e.g. WhisperEngine reload).
@MainActor
final class SettingsStore: ObservableObject {
    static let suiteName = "com.voxly.app"

    private enum Key {
        static let selectedModelSize     = "selectedModelSize"
        static let selectedInputDeviceUID = "selectedInputDeviceUID"
        static let pasteMode             = "pasteMode"
        static let languageOverride      = "languageOverride"
        static let launchAtLogin         = "launchAtLogin"
        static let showWindowOnLaunch    = "showWindowOnLaunch"
        static let historyRetentionDays  = "historyRetentionDays"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    private let defaults: UserDefaults

    @Published var selectedModelSize: ModelSize {
        didSet { defaults.set(selectedModelSize.rawValue, forKey: Key.selectedModelSize) }
    }

    /// CoreAudio UID of the chosen microphone, or the system-default sentinel.
    @Published var selectedInputDeviceUID: String {
        didSet { defaults.set(selectedInputDeviceUID, forKey: Key.selectedInputDeviceUID) }
    }

    @Published var pasteMode: PasteMode {
        didSet { defaults.set(pasteMode.rawValue, forKey: Key.pasteMode) }
    }

    @Published var languageOverride: String {
        didSet { defaults.set(languageOverride, forKey: Key.languageOverride) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Key.launchAtLogin)
            applyLaunchAtLogin(launchAtLogin)
        }
    }

    @Published var showWindowOnLaunch: Bool {
        didSet { defaults.set(showWindowOnLaunch, forKey: Key.showWindowOnLaunch) }
    }

    @Published var historyRetentionDays: Int {
        didSet { defaults.set(historyRetentionDays, forKey: Key.historyRetentionDays) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let rawModel = defaults.string(forKey: Key.selectedModelSize) ?? ModelSize.base.rawValue
        self.selectedModelSize = ModelSize(rawValue: rawModel) ?? .base

        self.selectedInputDeviceUID = defaults.string(forKey: Key.selectedInputDeviceUID)
            ?? AudioInputDevice.systemDefaultUID

        let rawPaste = defaults.string(forKey: Key.pasteMode) ?? PasteMode.paste.rawValue
        self.pasteMode = PasteMode(rawValue: rawPaste) ?? .paste

        self.languageOverride = defaults.string(forKey: Key.languageOverride) ?? "auto"

        // Bool defaults read as false when missing — set explicit defaults via
        // `object(forKey:)` test so we can pick our own defaults on first launch.
        self.launchAtLogin = defaults.object(forKey: Key.launchAtLogin) as? Bool ?? false
        self.showWindowOnLaunch = defaults.object(forKey: Key.showWindowOnLaunch) as? Bool ?? true
        self.historyRetentionDays = defaults.object(forKey: Key.historyRetentionDays) as? Int ?? 0
        self.hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
    }

    // MARK: launch-at-login (SMAppService, macOS 13+)

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                log.info("Registered launch-at-login")
            } else {
                try SMAppService.mainApp.unregister()
                log.info("Unregistered launch-at-login")
            }
        } catch {
            log.error("Launch-at-login toggle failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
