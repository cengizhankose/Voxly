import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            recordButton
            statusArea
            if !appState.transcribedText.isEmpty { lastTranscript }
            ThinDivider()
            PermissionsSectionView()
            ThinDivider()
            hotkeyRow
            ThinDivider()
            footer
        }
        .padding(16)
        .frame(width: 320)
        .background(Theme.bg)
        .foregroundColor(Theme.text)
        .tint(Theme.accent)
    }

    private var header: some View {
        HStack(spacing: 9) {
            BrandMark(size: 22)
            Text("Voxly")
                .font(Theme.display(16, .bold))
                .tracking(-0.3)
                .foregroundColor(Theme.text)
            Spacer()
            Text(appState.statusMessage)
                .font(Theme.mono(11))
                .foregroundColor(Theme.muted)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var recordButton: some View {
        Button(action: { appState.toggleDictation() }) {
            HStack(spacing: 8) {
                Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(appState.isRecording ? "Stop recording" : "Start recording")
                Spacer()
                Text("⌥D")
                    .font(Theme.mono(12, .semibold))
                    .opacity(0.85)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(appState.isTranscribing)
    }

    @ViewBuilder
    private var statusArea: some View {
        if appState.isRecording {
            RecordingChip()
        } else if appState.isTranscribing {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
                Text("Transcribing…")
                    .font(Theme.mono(12))
                    .foregroundColor(Theme.muted)
            }
        }
    }

    private var lastTranscript: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last").kickerStyle()
            Text(appState.transcribedText)
                .font(.system(size: 13))
                .foregroundColor(Theme.text)
                .textSelection(.enabled)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .voxlyCard(padding: 12)
    }

    private var hotkeyRow: some View {
        HStack {
            Text("Hotkey")
                .font(Theme.mono(11))
                .foregroundColor(Theme.muted)
            Spacer()
            KeyboardShortcuts.Recorder(for: .toggleDictation)
                .frame(maxWidth: 160)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            } label: {
                Text("Open Voxly").frame(maxWidth: .infinity)
            }
            .buttonStyle(GhostButtonStyle(compact: true))

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit").frame(maxWidth: .infinity)
            }
            .buttonStyle(GhostButtonStyle(compact: true))
        }
    }
}
