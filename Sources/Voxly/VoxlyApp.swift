import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleDictation = Self("toggleDictation", default: .init(.d, modifiers: .option))
}

@main
struct VoxlyApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
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
