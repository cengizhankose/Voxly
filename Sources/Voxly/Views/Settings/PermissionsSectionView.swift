import SwiftUI

/// Shared permissions UI used by both the menu bar popover and the desktop
/// Settings / main window. Renders microphone + accessibility status with
/// grant buttons and the stale-accessibility recovery hint.
struct PermissionsSectionView: View {
    @EnvironmentObject var appState: AppState

    /// Show the "Permissions" kicker. The menu bar wants it; a Settings
    /// `Section` already supplies its own header, so it can hide it.
    var showHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showHeader {
                Text("Permissions").kickerStyle()
            }

            PermissionRow(
                label: "Microphone",
                granted: appState.micPermissionGranted,
                action: { appState.permissionsManager.openMicrophoneSettings() }
            )

            PermissionRow(
                label: "Accessibility",
                granted: appState.accessibilityGranted,
                action: { appState.requestAccessibility() }
            )

            if appState.accessibilityLikelyStale && !appState.accessibilityGranted {
                StaleAccessibilityHint(appState: appState)
            }
        }
    }
}

struct StaleAccessibilityHint: View {
    let appState: AppState
    @State private var showConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.warning)
                    .font(.system(size: 11))
                Text("Voxly is already in System Settings → Accessibility, but macOS isn't trusting this build. Reset it and re-add a fresh entry.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Reset & Quit (then re-grant)") {
                showConfirm = true
            }
            .buttonStyle(GhostButtonStyle(compact: true))
        }
        .padding(10)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.warning.opacity(0.35), lineWidth: 1)
        )
        .confirmationDialog(
            "Reset Voxly's Accessibility permission and quit?",
            isPresented: $showConfirm
        ) {
            Button("Reset & Quit", role: .destructive) {
                appState.resetAccessibilityAndRelaunch()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("System Settings will open on the Accessibility pane. Re-add Voxly there, then relaunch the app.")
        }
    }
}

struct PermissionRow: View {
    let label: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundColor(granted ? Theme.positive : Theme.muted)
                .font(.system(size: 13))
            Text(label)
                .font(.system(size: 12.5))
                .foregroundColor(Theme.text)
            Spacer()
            if granted {
                Text("Granted")
                    .font(Theme.mono(10.5, .medium))
                    .foregroundColor(Theme.positive)
            } else {
                Button("Grant") { action() }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
            }
        }
    }
}
