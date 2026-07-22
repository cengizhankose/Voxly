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
                if let shortcutLabel {
                    Text(shortcutLabel)
                        .font(Theme.mono(12, .semibold))
                        .opacity(0.85)
                }
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

    /// Current binding, or nil when unbound. Shared by the record button hint
    /// and the hotkey row so they can never disagree after a rebind.
    private var shortcutLabel: String? {
        KeyboardShortcuts.getShortcut(for: .toggleDictation).map(String.init(describing:))
    }

    // Deliberately NOT a `KeyboardShortcuts.Recorder`: focusing a recorder sets
    // `KeyboardShortcuts.isPaused = true`, and the menu-bar panel is a
    // non-activating window that never resigns key on dismiss — so the pause
    // sticks and the global hotkey stays dead until relaunch. Rebinding lives
    // in Settings/Onboarding, whose real windows unpause correctly.
    private var hotkeyRow: some View {
        HStack {
            Text("Hotkey")
                .font(Theme.mono(11))
                .foregroundColor(Theme.muted)
            Spacer()
            Text(shortcutLabel ?? "None")
                .font(Theme.mono(12, .semibold))
                .foregroundColor(Theme.text)
        }
        .help("Change the hotkey in Settings — Open Voxly → Settings")
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
