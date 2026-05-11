import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: appState.isRecording ? "mic.fill" : "mic")
                    .foregroundColor(appState.isRecording ? .red : .primary)
                    .font(.title2)
                Text("Voxly")
                    .font(.headline)
                Spacer()
                Text(appState.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Recording button
            Button(action: { appState.toggleDictation() }) {
                HStack {
                    Image(systemName: appState.isRecording ? "stop.circle.fill" : "record.circle")
                        .foregroundColor(appState.isRecording ? .red : .accentColor)
                    Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                    Spacer()
                    Text("Option+D")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(appState.isTranscribing)

            if appState.isTranscribing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Transcribing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Last transcription
            if !appState.transcribedText.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last transcription:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(appState.transcribedText)
                        .font(.body)
                        .textSelection(.enabled)
                        .lineLimit(5)
                }
            }

            Divider()

            // Permissions
            VStack(alignment: .leading, spacing: 6) {
                Text("Permissions")
                    .font(.caption)
                    .foregroundColor(.secondary)

                PermissionRow(
                    label: "Microphone",
                    granted: appState.micPermissionGranted,
                    action: {
                        appState.permissionsManager.openMicrophoneSettings()
                    }
                )

                PermissionRow(
                    label: "Accessibility",
                    granted: appState.accessibilityGranted,
                    action: {
                        appState.requestAccessibility()
                    }
                )
            }

            Divider()

            // Hotkey setting
            HStack {
                Text("Hotkey:")
                    .font(.caption)
                Spacer()
                KeyboardShortcuts.Recorder(for: .toggleDictation)
                    .frame(maxWidth: 150)
            }

            Divider()

            Button("Quit Voxly") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct PermissionRow: View {
    let label: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(granted ? .green : .red)
                .font(.caption)
            Text(label)
                .font(.caption)
            Spacer()
            if !granted {
                Button("Grant") { action() }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
    }
}
