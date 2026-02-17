import SwiftUI
import KeyboardShortcuts

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
    private let permissionsManager = PermissionsManager()

    init() {
        Task {
            await setupHotkey()
            await checkPermissions()
            await loadModel()
        }
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
        accessibilityGranted = permissionsManager.checkAccessibility()
    }

    private func loadModel() async {
        statusMessage = "Loading model..."
        let modelPath = modelFilePath()

        guard FileManager.default.fileExists(atPath: modelPath) else {
            statusMessage = "Model not found. Run download script first."
            return
        }

        let loaded = await whisperEngine.loadModel(path: modelPath)
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

        Task {
            let audioData = audioRecorder.getAudioData()

            guard !audioData.isEmpty else {
                statusMessage = "No audio captured"
                isTranscribing = false
                return
            }

            let text = await whisperEngine.transcribe(audioData: audioData)

            if text.isEmpty {
                statusMessage = "No speech detected"
            } else {
                transcribedText = text
                statusMessage = "Inserting text..."

                if accessibilityGranted {
                    textInserter.insertText(text)
                    statusMessage = "Done"
                } else {
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
