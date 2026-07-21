import SwiftUI
import AppKit
import Combine
import KeyboardShortcuts
import os

private let log = Logger(subsystem: "com.voxly.app", category: "AppState")

@MainActor
final class AppState: ObservableObject {
    // Permissions
    @Published var micPermissionGranted = false
    @Published var accessibilityGranted = false
    /// True when user clicked Grant for Accessibility and ~8s of polling
    /// elapsed without the state flipping — strong signal of a stale TCC
    /// entry from a previous CDHash. Surfaces a "Reset & Re-grant" path.
    @Published var accessibilityLikelyStale = false

    // Sub-components
    let dictation = DictationController()
    let history = HistoryStore()
    let settings = SettingsStore()
    let downloader = ModelDownloader()
    let permissionsManager = PermissionsManager()

    // MARK: convenience pass-throughs for existing call sites.
    var isRecording: Bool { dictation.isRecording }
    var isTranscribing: Bool { dictation.isTranscribing }
    var statusMessage: String { dictation.statusMessage }
    var transcribedText: String { dictation.lastTranscript }

    private var permissionPollTimer: Timer?
    private var permissionPollStartedAt: Date?
    private var cancellables = Set<AnyCancellable>()
    private var distributedTCCObserver: NSObjectProtocol?

    init() {
        // Apply persisted settings BEFORE first model load.
        dictation.pasteMode = settings.pasteMode
        dictation.languageOverride = settings.languageOverride
        dictation.audioRecorder.preferredDeviceUID = settings.selectedInputDeviceUID
        history.retentionDays = settings.historyRetentionDays

        Task {
            setupHotkey()
            await checkPermissions()
            await loadInitialModel()
        }
        observeAppActivation()
        observeTCCChanges()
        wireDictationToHistory()
        wireSettingsToDictation()
        forwardChildChanges()
    }

    /// Re-emit child ObservableObjects' change notifications through AppState.
    /// Views observe only `appState` (the single `@EnvironmentObject`), so
    /// without this bridge a change to `settings`, `downloader`, `dictation` or
    /// `history` fires that child's `objectWillChange` but never AppState's —
    /// leaving the UI stale until an unrelated redraw. Forwarding makes nested
    /// store mutations (model selection, download progress, ...) reactive.
    private func forwardChildChanges() {
        for publisher in [
            dictation.objectWillChange,
            settings.objectWillChange,
            downloader.objectWillChange,
            history.objectWillChange
        ] {
            publisher
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    deinit {
        if let token = distributedTCCObserver {
            DistributedNotificationCenter.default().removeObserver(token)
        }
    }

    private func wireDictationToHistory() {
        dictation.onTranscript = { [weak self] text, duration, targetApp, language, modelName in
            guard let self = self else { return }
            let record = TranscriptionRecord(
                text: text,
                durationSeconds: duration,
                language: language,
                targetAppBundleId: targetApp?.bundleIdentifier,
                targetAppName: targetApp?.localizedName,
                modelName: modelName
            )
            self.history.append(record)
        }
    }

    /// Bridge settings changes into the controller. Combine sinks fire on the
    /// main actor since SettingsStore is `@MainActor`.
    private func wireSettingsToDictation() {
        settings.$pasteMode
            .sink { [weak self] mode in
                self?.dictation.pasteMode = mode
            }
            .store(in: &cancellables)

        settings.$languageOverride
            .sink { [weak self] lang in
                self?.dictation.languageOverride = lang
            }
            .store(in: &cancellables)

        settings.$selectedInputDeviceUID
            .sink { [weak self] uid in
                self?.dictation.audioRecorder.preferredDeviceUID = uid
            }
            .store(in: &cancellables)

        settings.$historyRetentionDays
            .sink { [weak self] days in
                self?.history.retentionDays = days
            }
            .store(in: &cancellables)

        // Model switching — skip first emission (initial value already applied at boot).
        settings.$selectedModelSize
            .dropFirst()
            .sink { [weak self] size in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.applyModelChange(size)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: hotkey

    // Logs here are `notice`-level on purpose: macOS persists notice and above,
    // while `info` is memory-only — invisible after the fact. This is the
    // primary diagnostic for "hotkey pressed but nothing happened" reports.
    private func setupHotkey() {
        KeyboardShortcuts.onKeyDown(for: .toggleDictation) { [weak self] in
            log.notice("Hotkey fired")
            Task { @MainActor in
                self?.toggleDictation()
            }
        }
        let shortcut = KeyboardShortcuts.getShortcut(for: .toggleDictation)
        log.notice("Hotkey handler registered; shortcut=\(shortcut.map(String.init(describing:)) ?? "nil", privacy: .public)")
    }

    func toggleDictation() {
        dictation.toggle(
            micGranted: micPermissionGranted,
            accessibilityGranted: accessibilityGranted
        )
    }

    // MARK: permissions

    func checkPermissions() async {
        micPermissionGranted = await permissionsManager.requestMicrophoneAccess()
        let prev = accessibilityGranted
        accessibilityGranted = permissionsManager.checkAccessibility()
        if prev != accessibilityGranted {
            log.info("Accessibility changed: \(prev) -> \(self.accessibilityGranted)")
        }
    }

    func refreshPermissions() {
        let prevAcc = accessibilityGranted
        let prevMic = micPermissionGranted
        accessibilityGranted = permissionsManager.checkAccessibility()
        micPermissionGranted = permissionsManager.checkMicrophoneAccessSync()
        if prevAcc != accessibilityGranted || prevMic != micPermissionGranted {
            log.info("Permissions refreshed: mic \(prevMic)->\(self.micPermissionGranted), acc \(prevAcc)->\(self.accessibilityGranted)")
        }
    }

    func requestAccessibility() {
        permissionsManager.promptAccessibility()
        // Also deep-link to Settings in case the prompt was suppressed (modern
        // macOS frequently no-ops the legacy prompt when bundle id is already
        // registered, even if the entry is stale).
        permissionsManager.openAccessibilitySettings()
        accessibilityLikelyStale = false
        startPermissionPolling()
    }

    /// Wipe Voxly's TCC entry then relaunch so a fresh grant binds to the
    /// current CDHash. Required for ad-hoc-signed dev builds; harmless under
    /// stable signing.
    func resetAccessibilityAndRelaunch() {
        log.info("Resetting Accessibility TCC entry and relaunching")
        _ = permissionsManager.resetAccessibility()
        permissionsManager.openAccessibilitySettings()
        // Spawn a detached helper that waits for THIS process to exit, then
        // reopens the bundle. Without this the app just quit and never came
        // back. `open` coalesces to a single instance, so the sleep must
        // outlast our own terminate delay below.
        let bundlePath = Bundle.main.bundlePath
        let relauncher = Process()
        relauncher.launchPath = "/bin/sh"
        relauncher.arguments = ["-c", "sleep 1.5; /usr/bin/open \"\(bundlePath)\""]
        do {
            try relauncher.run()
        } catch {
            log.error("Relaunch helper failed: \(error.localizedDescription, privacy: .public)")
        }
        // Give Settings + helper a moment to register, then exit. This
        // deliberately avoids `NSApp.terminate`: SwiftUI can defer or swallow
        // it while the popover's confirmation dialog is unwinding, leaving the
        // app running and this flow stuck. There is no state to tear down, and
        // the detached helper above relaunches the bundle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            log.notice("Reset flow exiting for relaunch")
            exit(0)
        }
    }

    private func observeAppActivation() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissions() }
        }
    }

    private func startPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollStartedAt = Date()

        // Use .common run-loop mode so the timer keeps firing while sheets or
        // menu-bar popovers run a modal session.
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { timer.invalidate(); return }
                self.refreshPermissions()
                if self.accessibilityGranted {
                    timer.invalidate()
                    self.permissionPollTimer = nil
                    self.accessibilityLikelyStale = false
                    log.info("Stopped permission polling after grant")
                    return
                }
                // After ~8s of polling without flipping, the entry is almost
                // certainly stale (csreq mismatch). Surface the reset path.
                if let started = self.permissionPollStartedAt,
                   Date().timeIntervalSince(started) > 8,
                   !self.accessibilityLikelyStale {
                    self.accessibilityLikelyStale = true
                    log.warning("Accessibility grant did not propagate in 8s — likely stale TCC entry")
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionPollTimer = timer

        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.permissionPollTimer?.invalidate()
            self?.permissionPollTimer = nil
        }
    }

    /// Listen for TCC modifications so we can refresh state instantly when the
    /// user toggles Voxly in System Settings. Stable, undocumented Apple notif.
    private func observeTCCChanges() {
        distributedTCCObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.TCC.access.changed"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissions() }
        }
    }

    // MARK: model

    private func loadInitialModel() async {
        let size = settings.selectedModelSize
        if let path = ModelLocator.path(for: size) {
            await dictation.loadModel(at: path, name: size.rawValue)
        } else if let fallbackPath = ModelLocator.path(for: .base) {
            log.warning("Selected model \(size.rawValue, privacy: .public) unavailable, falling back to base")
            await dictation.loadModel(at: fallbackPath, name: ModelSize.base.rawValue)
        } else {
            log.error("No model files available on disk")
        }
    }

    private func applyModelChange(_ size: ModelSize) async {
        guard let path = ModelLocator.path(for: size) else {
            log.error("Cannot switch to \(size.rawValue, privacy: .public): file missing")
            // Revert the picker so UI matches reality.
            settings.selectedModelSize = ModelSize(rawValue: dictation.currentModelName) ?? .base
            return
        }
        await dictation.reloadModel(at: path, name: size.rawValue)
    }
}
