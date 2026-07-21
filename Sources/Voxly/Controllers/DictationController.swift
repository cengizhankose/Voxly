import Foundation
import AppKit
import os

private let log = Logger(subsystem: "com.voxly.app", category: "DictationController")

@MainActor
final class DictationController: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var statusMessage = "Loading model..."
    @Published private(set) var lastTranscript = ""
    @Published private(set) var currentModelName: String = ModelSize.base.rawValue
    /// Briefly true after a cycle that produced no usable speech, so the menu
    /// bar icon can signal the miss — otherwise an empty transcription is
    /// indistinguishable from the app being broken (status text lives inside
    /// the closed popover).
    @Published private(set) var lastCycleProducedNoSpeech = false

    /// Paste behaviour applied at the end of a transcription.
    var pasteMode: PasteMode = .paste

    /// Language hint passed to whisper ("auto" disables override).
    var languageOverride: String = "auto"

    /// Called after a successful transcription.
    var onTranscript: ((_ text: String, _ duration: TimeInterval, _ targetApp: NSRunningApplication?, _ language: String?, _ modelName: String) -> Void)?

    let audioRecorder = AudioRecorder()
    let whisperEngine = WhisperEngine()
    let textInserter = TextInserter()

    private var recordingStartedAt: Date?

    /// True once `loadModel` has succeeded. Recording is allowed only after this flips.
    private(set) var modelReady = false
    private(set) var isReloadingModel = false

    func loadModel(at path: String, name: String) async {
        statusMessage = "Loading model..."
        log.info("Model path resolved: \(path, privacy: .public)")
        guard FileManager.default.fileExists(atPath: path) else {
            log.error("Model file missing at: \(path, privacy: .public)")
            statusMessage = "Model not found. Run download script first."
            return
        }
        let loaded = await whisperEngine.loadModel(path: path)
        log.info("Model loaded: \(loaded) (\(name, privacy: .public))")
        modelReady = loaded
        currentModelName = name
        statusMessage = loaded ? "Ready" : "Failed to load model"
    }

    /// Paste arbitrary text (e.g. from history) into the last external app.
    /// Falls back to clipboard if no external app is known.
    /// - Returns: true when paste was synthesized, false when only clipboard was written.
    @discardableResult
    func pasteFromHistory(_ text: String, accessibilityGranted: Bool) -> Bool {
        guard accessibilityGranted else {
            textInserter.copyToClipboard(text)
            log.info("History paste fell back to clipboard (no Accessibility)")
            return false
        }
        return textInserter.insertTextIntoLastExternalApp(text)
    }

    var lastExternalAppName: String? { textInserter.lastExternalApp?.localizedName }

    /// Swap to a different model file. Refuses while recording/transcribing.
    func reloadModel(at path: String, name: String) async {
        guard !isRecording, !isTranscribing else {
            log.warning("Refusing model reload during active dictation")
            return
        }
        guard FileManager.default.fileExists(atPath: path) else {
            log.error("Reload target missing: \(path, privacy: .public)")
            statusMessage = "Model file not found"
            return
        }
        isReloadingModel = true
        statusMessage = "Applying model change..."
        modelReady = false
        let loaded = await whisperEngine.reloadModel(path: path)
        modelReady = loaded
        isReloadingModel = false
        currentModelName = loaded ? name : currentModelName
        statusMessage = loaded ? "Ready" : "Failed to load model"
        log.info("Model reload result: \(loaded) (\(name, privacy: .public))")
    }

    func toggle(micGranted: Bool, accessibilityGranted: Bool) {
        if isRecording {
            stop(accessibilityGranted: accessibilityGranted)
        } else {
            start(micGranted: micGranted)
        }
    }

    private func start(micGranted: Bool) {
        guard micGranted else {
            statusMessage = "Microphone access denied"
            return
        }
        guard modelReady, !isReloadingModel else {
            statusMessage = isReloadingModel ? "Applying model change..." : "Model not ready"
            return
        }

        textInserter.captureFrontmostApp()
        recordingStartedAt = Date()

        do {
            try audioRecorder.start()
            isRecording = true
            statusMessage = "Recording..."
            log.notice("Recording started")
        } catch {
            log.error("Failed to start recording: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    private func stop(accessibilityGranted: Bool) {
        audioRecorder.stop()
        isRecording = false
        statusMessage = "Transcribing..."
        isTranscribing = true
        log.notice("Recording stopped, starting transcription")

        let startedAt = recordingStartedAt ?? Date()
        let duration = Date().timeIntervalSince(startedAt)
        let target = textInserter.targetApp

        Task {
            let audioData = audioRecorder.getAudioData()
            log.notice("Captured \(audioData.count) audio samples (~\(Double(audioData.count) / 16000.0, format: .fixed(precision: 2))s)")

            guard !audioData.isEmpty else {
                log.error("No audio data captured")
                statusMessage = "No audio captured"
                isTranscribing = false
                return
            }

            let langHint: String? = (languageOverride == "auto" || languageOverride.isEmpty) ? nil : languageOverride
            let raw = await whisperEngine.transcribe(audioData: audioData, language: langHint)
            let text = Self.cleanTranscript(raw)
            log.notice("Transcription length raw=\(raw.count) cleaned=\(text.count)")

            if text.isEmpty {
                statusMessage = "No speech detected"
                signalNoSpeech()
            } else {
                lastTranscript = text

                deliver(text: text, accessibilityGranted: accessibilityGranted)
                onTranscript?(text, duration, target, langHint, currentModelName)
            }
            isTranscribing = false
        }
    }

    /// Audible + visual cue that the cycle completed but yielded nothing:
    /// system sound now, `mic.slash` menu bar icon for a few seconds.
    private func signalNoSpeech() {
        NSSound(named: "Basso")?.play()
        lastCycleProducedNoSpeech = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            lastCycleProducedNoSpeech = false
        }
    }

    /// Strip whisper placeholder tokens like `[BLANK_AUDIO]`, `[Music]`,
    /// `(silence)` etc., then trim. Returns empty string when the model
    /// produced only placeholders.
    private static func cleanTranscript(_ s: String) -> String {
        // Whisper emits bracketed/parenthesised tags for non-speech audio.
        // Match `[...]` or `(...)` whose contents are letters / spaces /
        // underscores / hyphens only (avoids eating real punctuation inside
        // real transcripts like "I said (loudly)").
        let pattern = #"[\[\(\*]\s*[A-Za-z _\-]+\s*[\]\)\*]"#
        let cleaned = s.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Apply the configured paste mode. Falls back to clipboard whenever
    /// Accessibility isn't granted, regardless of preference.
    private func deliver(text: String, accessibilityGranted: Bool) {
        let effectiveMode: PasteMode = accessibilityGranted ? pasteMode : .clipboard

        switch effectiveMode {
        case .paste:
            log.info("Inserting text via Cmd+V")
            textInserter.insertText(text)
            statusMessage = "Done"
        case .clipboard:
            log.info("Clipboard-only delivery")
            textInserter.copyToClipboard(text)
            statusMessage = accessibilityGranted
                ? "Copied to clipboard"
                : "Text copied (enable Accessibility for auto-paste)"
        case .both:
            log.info("Paste + leave on clipboard")
            textInserter.insertText(text)
            statusMessage = "Done (clipboard kept)"
        }
    }
}
