import SwiftUI
import AppKit
import KeyboardShortcuts

/// The macOS Settings (⌘,) scene. Fixed-size wrapper around `SettingsContent`.
struct SettingsView: View {
    var body: some View {
        SettingsContent()
            .frame(width: 540, height: 400)
            .padding(20)
            .background(Theme.bg)
            .tint(Theme.accent)
    }
}

/// Reusable settings tabs — embedded both in the Settings scene and the main
/// window's Settings sidebar section so the desktop app exposes every menu bar
/// feature (hotkey, permissions, model, advanced).
struct SettingsContent: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }

            PermissionsSettingsView()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }

            ModelSettingsView()
                .tabItem { Label("Model", systemImage: "cube.box") }

            AdvancedSettingsView()
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
    }
}

// MARK: Permissions

private struct PermissionsSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
                PermissionsSectionView(showHeader: false)
            } header: {
                Text("System Access")
            } footer: {
                Text("Microphone is required to record. Accessibility lets Voxly paste the transcript into the active app via synthesized ⌘V; without it, text is copied to the clipboard only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { appState.refreshPermissions() }
    }
}

// MARK: General

private struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showClearConfirm = false
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch Voxly at login", isOn: Binding(
                    get: { appState.settings.launchAtLogin },
                    set: { appState.settings.launchAtLogin = $0 }
                ))
                Toggle("Show main window when launched", isOn: Binding(
                    get: { appState.settings.showWindowOnLaunch },
                    set: { appState.settings.showWindowOnLaunch = $0 }
                ))
            }

            Section("Hotkey") {
                HStack {
                    Text("Toggle dictation")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleDictation)
                        .frame(maxWidth: 200)
                }
            }

            Section("History") {
                Picker("Retention", selection: Binding(
                    get: { appState.settings.historyRetentionDays },
                    set: { appState.settings.historyRetentionDays = $0 }
                )) {
                    Text("Forever").tag(0)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear All History", systemImage: "trash")
                }
                .disabled(appState.history.records.isEmpty)
            }

            Section {
                Button {
                    showResetConfirm = true
                } label: {
                    Label("Reset Accessibility Permission", systemImage: "arrow.counterclockwise")
                }
                Text("Use if Voxly says \"Accessibility not granted\" even after you've enabled it. Wipes the TCC entry and quits, then re-add Voxly in System Settings and relaunch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Troubleshooting")
            }
        }
        .formStyle(.grouped)
        .alert("Clear all transcription history?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                appState.history.clearAll()
            }
        } message: {
            Text("\(appState.history.records.count) records will be permanently removed from disk.")
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
}

// MARK: Model

private struct ModelSettingsView: View {
    var body: some View {
        ModelManagementView()
    }
}

// MARK: Advanced

private struct AdvancedSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Output") {
                Picker("Paste mode", selection: Binding(
                    get: { appState.settings.pasteMode },
                    set: { appState.settings.pasteMode = $0 }
                )) {
                    ForEach(PasteMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Text("Voxly falls back to clipboard if Accessibility isn't granted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Recognition") {
                Picker("Language", selection: Binding(
                    get: { appState.settings.languageOverride },
                    set: { appState.settings.languageOverride = $0 }
                )) {
                    Text("Auto-detect").tag("auto")
                    Text("English").tag("en")
                    Text("Spanish").tag("es")
                    Text("French").tag("fr")
                    Text("German").tag("de")
                    Text("Turkish").tag("tr")
                    Text("Japanese").tag("ja")
                    Text("Chinese").tag("zh")
                }
            }
        }
        .formStyle(.grouped)
    }
}
