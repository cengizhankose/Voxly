import SwiftUI
import KeyboardShortcuts

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case microphone
    case accessibility
    case hotkey
    case done
}

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    @State private var step: OnboardingStep = .welcome
    @State private var hotkeyFired = false

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            ThinDivider()

            controls
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(width: 560, height: 420)
        .background(Theme.bg)
        .tint(Theme.accent)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:        WelcomeStep()
        case .microphone:     MicrophoneStep()
        case .accessibility:  AccessibilityStep()
        case .hotkey:         HotkeyStep(fired: $hotkeyFired)
        case .done:           DoneStep()
        }
    }

    private var controls: some View {
        HStack {
            stepIndicator
            Spacer()
            Button("Back", action: back)
                .buttonStyle(GhostButtonStyle(compact: true))
                .disabled(step == .welcome)
            Button(step == .done ? "Finish" : "Next") {
                advance()
            }
            .buttonStyle(PrimaryButtonStyle(compact: true))
            .keyboardShortcut(.defaultAction)
            .disabled(!canAdvance)
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                Circle()
                    .fill(s.rawValue <= step.rawValue ? Theme.accent : Theme.border)
                    .frame(width: 7, height: 7)
            }
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .welcome:        return true
        case .microphone:     return appState.micPermissionGranted
        case .accessibility:  return appState.accessibilityGranted
        case .hotkey:         return hotkeyFired
        case .done:           return true
        }
    }

    private func advance() {
        if step == .done {
            appState.settings.hasCompletedOnboarding = true
            isPresented = false
            return
        }
        if let next = OnboardingStep(rawValue: step.rawValue + 1) {
            step = next
        }
    }

    private func back() {
        if let prev = OnboardingStep(rawValue: step.rawValue - 1) {
            step = prev
        }
    }

}

// MARK: steps

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 16) {
            BrandMark(size: 64)
            Text("Welcome to Voxly").displayStyle(34).foregroundColor(Theme.text)
            Text("Press Option+D anywhere on your Mac to dictate. Voxly transcribes locally. Your voice never leaves the device.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.muted)
                .frame(maxWidth: 420)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

private struct MicrophoneStep: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        StepShell(
            icon: "mic.fill",
            title: "Microphone access",
            subtitle: "Voxly needs to listen to your voice to transcribe it.",
            status: appState.micPermissionGranted
                ? "Microphone access granted"
                : "Click below to grant access."
        ) {
            if appState.micPermissionGranted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(Theme.positive)
            } else {
                Button("Grant Microphone Access") {
                    Task { await appState.checkPermissions() }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

private struct AccessibilityStep: View {
    @EnvironmentObject var appState: AppState
    @State private var showResetConfirm = false

    var body: some View {
        StepShell(
            icon: "hand.tap.fill",
            title: "Accessibility access",
            subtitle: "Required so Voxly can paste your transcript into the focused app via synthesized Cmd+V.",
            status: status
        ) {
            VStack(spacing: 10) {
                if appState.accessibilityGranted {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .foregroundColor(Theme.positive)
                } else {
                    Button("Grant Accessibility Access") {
                        appState.requestAccessibility()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                if appState.accessibilityLikelyStale && !appState.accessibilityGranted {
                    Button("Reset & Quit (then re-grant)") {
                        showResetConfirm = true
                    }
                    .buttonStyle(GhostButtonStyle(compact: true))
                    Text("Looks like macOS has a stale entry for Voxly from a previous build. Reset it to register the current binary.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
            }
        }
        .confirmationDialog(
            "Reset Voxly's Accessibility permission and quit?",
            isPresented: $showResetConfirm
        ) {
            Button("Reset & Quit", role: .destructive) {
                appState.resetAccessibilityAndRelaunch()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("System Settings will open on the Accessibility pane. Re-add Voxly there, then relaunch the app.")
        }
    }

    private var status: String {
        if appState.accessibilityGranted { return "Accessibility access granted" }
        if appState.accessibilityLikelyStale {
            return "Stale TCC entry detected. Use Reset below."
        }
        return "Click Grant, then enable Voxly in System Settings."
    }
}

private struct HotkeyStep: View {
    @EnvironmentObject var appState: AppState
    @Binding var fired: Bool

    /// Bumped on every captured press. Used as a SwiftUI `.id()` so the green
    /// label re-mounts and the appearance transition replays per press.
    @State private var pressCount: UInt = 0
    @State private var pulseVisible = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        StepShell(
            icon: "keyboard",
            title: "Try the hotkey",
            subtitle: "Press your dictation hotkey to confirm it works. You can rebind it here if needed.",
            status: fired ? "Hotkey detected. Feel free to test again." : "Press the hotkey to continue."
        ) {
            VStack(spacing: 16) {
                KeyboardShortcuts.Recorder(for: .toggleDictation)
                    .frame(maxWidth: 220)

                feedback
                    .frame(height: 24) // reserve to prevent layout shift
            }
        }
        // dropFirst skips the @Published initial-value emission so we only react
        // to actual presses, not to view-attach.
        .onReceive(appState.dictation.$isRecording.dropFirst()) { _ in
            triggerPulse()
        }
        .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
        }
    }

    @ViewBuilder
    private var feedback: some View {
        ZStack {
            if pulseVisible {
                Label("Hotkey fired", systemImage: "checkmark.circle.fill")
                    .foregroundColor(Theme.positive)
                    .id(pressCount) // re-mount each press → transition replays
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else if !fired {
                Label("Waiting for hotkey press...", systemImage: "ellipsis.circle")
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: pulseVisible)
        .animation(.easeInOut(duration: 0.18), value: pressCount)
    }

    private func triggerPulse() {
        fired = true
        pressCount &+= 1
        pulseVisible = true

        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            pulseVisible = false
        }
    }
}

private struct DoneStep: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(Theme.positive)
            Text("You're all set!").displayStyle(34).foregroundColor(Theme.text)
            Text("Press your hotkey anywhere to dictate. Voxly stays in your menu bar. Use the dock icon to open this window again any time.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.muted)
                .frame(maxWidth: 420)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

// MARK: shell

private struct StepShell<Action: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let status: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Theme.accentSoft).frame(width: 92, height: 92)
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(Theme.accentText)
            }
            Text(title).displayStyle(28).foregroundColor(Theme.text)
            Text(subtitle)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.muted)
                .frame(maxWidth: 420)

            action()
                .padding(.top, 4)

            Text(status)
                .font(Theme.mono(11))
                .foregroundColor(Theme.muted)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

