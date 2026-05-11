import SwiftUI
import AppKit
import KeyboardShortcuts
import os

private let log = Logger(subsystem: "com.voxly.app", category: "AppState")

@MainActor
final class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var transcribedText = ""
    @Published var statusMessage = "Ready"
    @Published var micPermissionGranted = false
    @Published var accessibilityGranted = false

    private let audioRecorder = AudioRecorder()
    private let whisperEngine = WhisperEngine()
    private let textInserter = TextInserter()
    let permissionsManager = PermissionsManager()
    private var permissionPollTimer: Timer?

    init() {
        Task {
            await setupHotkey()
            await checkPermissions()
            await loadModel()
        }
        observeAppActivation()
    }

    private func setupHotkey() {
        KeyboardShortcuts.onKeyDown(for: .toggleDictation) { [weak self] in
            Task { @MainActor in
                self?.toggleDictation()
            }
        }
    }

    func checkPermissions() async {
        micPermissionGranted = await permissionsManager.requestMicrophoneAccess()
        let prev = accessibilityGranted
        accessibilityGranted = permissionsManager.checkAccessibility()
        if prev != accessibilityGranted {
            log.info("Accessibility changed: \(prev) -> \(self.accessibilityGranted)")
        }
    }

    /// Re-check Accessibility without prompting. Mic status is sticky after grant
    /// (TCC reports it without prompt), so single call is fine.
    func refreshPermissions() {
        let prevAcc = accessibilityGranted
        let prevMic = micPermissionGranted
        accessibilityGranted = permissionsManager.checkAccessibility()
        micPermissionGranted = permissionsManager.checkMicrophoneAccessSync()
        if prevAcc != accessibilityGranted || prevMic != micPermissionGranted {
            log.info("Permissions refreshed: mic \(prevMic)->\(self.micPermissionGranted), acc \(prevAcc)->\(self.accessibilityGranted)")
        }
    }

    /// Open Accessibility settings, then poll for grant so UI updates without
    /// requiring app focus change.
    func requestAccessibility() {
        permissionsManager.promptAccessibility()
        startPermissionPolling()
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
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { timer.invalidate(); return }
                self.refreshPermissions()
                if self.accessibilityGranted {
                    timer.invalidate()
                    self.permissionPollTimer = nil
                    log.info("Stopped permission polling after grant")
                }
            }
        }
        // Auto-stop after 60s regardless to avoid leak
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.permissionPollTimer?.invalidate()
            self?.permissionPollTimer = nil
        }
    }

    private func loadModel() async {
        statusMessage = "Loading model..."
        let modelPath = modelFilePath()
        log.info("Model path resolved: \(modelPath, privacy: .public)")

        guard FileManager.default.fileExists(atPath: modelPath) else {
            log.error("Model file missing at: \(modelPath, privacy: .public)")
            statusMessage = "Model not found. Run download script first."
            return
        }

        let loaded = await whisperEngine.loadModel(path: modelPath)
        log.info("Model loaded: \(loaded)")
        statusMessage = loaded ? "Ready" : "Failed to load model"
    }

    func toggleDictation() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard micPermissionGranted else {
            statusMessage = "Microphone access denied"
            return
        }

        // Capture the app that owns the focused text field BEFORE we touch
        // the menu bar UI / popover, so paste can target it later.
        textInserter.captureFrontmostApp()

        do {
            try audioRecorder.start()
            isRecording = true
            statusMessage = "Recording..."
        } catch {
            statusMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        audioRecorder.stop()
        isRecording = false
        statusMessage = "Transcribing..."
        isTranscribing = true
        log.info("Recording stopped, starting transcription")

        Task {
            let audioData = audioRecorder.getAudioData()
            log.info("Captured \(audioData.count) audio samples (~\(Double(audioData.count) / 16000.0, format: .fixed(precision: 2))s)")

            guard !audioData.isEmpty else {
                log.error("No audio data captured")
                statusMessage = "No audio captured"
                isTranscribing = false
                return
            }

            let text = await whisperEngine.transcribe(audioData: audioData)
            log.info("Transcription result: '\(text, privacy: .public)' (length: \(text.count))")

            if text.isEmpty {
                statusMessage = "No speech detected"
            } else {
                transcribedText = text
                statusMessage = "Inserting text..."

                if accessibilityGranted {
                    log.info("Inserting text via Cmd+V")
                    textInserter.insertText(text)
                    statusMessage = "Done"
                } else {
                    log.warning("Accessibility not granted, clipboard only")
                    statusMessage = "Text copied (enable Accessibility for auto-paste)"
                    textInserter.copyToClipboard(text)
                }
            }
            isTranscribing = false
        }
    }

    private func modelFilePath() -> String {
        // Check app bundle first
        if let bundlePath = Bundle.main.path(forResource: "ggml-base", ofType: "bin") {
            return bundlePath
        }

        // Check Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let voxlyDir = appSupport.appendingPathComponent("Voxly")
        return voxlyDir.appendingPathComponent("ggml-base.bin").path
    }
}
