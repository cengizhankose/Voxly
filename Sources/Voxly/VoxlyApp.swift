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
        windowScene
            .commands {
                // Hide the default "New" item — Voxly has no document model.
                CommandGroup(replacing: .newItem) { }
            }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .tint(Theme.accent)
        }

        menuBarExtra
    }

    private var windowScene: some Scene {
        Window("Voxly", id: "main") {
            MainWindowView()
                .environmentObject(appState)
                .tint(Theme.accent)
        }
    }

    private var menuBarExtra: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Label {
                Text("Voxly")
            } icon: {
                Image(systemName: menuBarSymbol)
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarSymbol: String {
        if appState.isRecording { return "mic.fill" }
        if appState.dictation.lastCycleProducedNoSpeech { return "mic.slash" }
        return "mic"
    }
}

