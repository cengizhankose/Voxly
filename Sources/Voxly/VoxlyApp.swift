import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleDictation = Self("toggleDictation", default: .init(.d, modifiers: .option))
}

@main
struct VoxlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        Window("Voxly", id: "main") {
            MainWindowView()
                .environmentObject(appState)
                .tint(Theme.accent)
        }
        .commands {
            // Hide the default "New" item — Voxly has no document model.
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .tint(Theme.accent)
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Label {
                Text("Voxly")
            } icon: {
                Image(systemName: appState.isRecording ? "mic.fill" : "mic")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

