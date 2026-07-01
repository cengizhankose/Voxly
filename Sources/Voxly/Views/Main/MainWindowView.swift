import SwiftUI

enum SidebarSection: String, Hashable, CaseIterable, Identifiable {
    case history
    case models
    case settings
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .history:  return "History"
        case .models:   return "Models"
        case .settings: return "Settings"
        case .about:    return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .history:  return "clock.arrow.circlepath"
        case .models:   return "cube.box"
        case .settings: return "gearshape"
        case .about:    return "info.circle"
        }
    }
}

struct MainWindowView: View {
    @EnvironmentObject var appState: AppState
    @State private var section: SidebarSection? = .history
    @State private var selectedRecordId: TranscriptionRecord.ID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showOnboarding = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(SidebarSection.allCases, selection: $section) { item in
                Label(item.label, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
            .navigationTitle("Voxly")
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .frame(minWidth: 820, minHeight: 480)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .environmentObject(appState)
                .interactiveDismissDisabled(true)
        }
        .onAppear {
            if !appState.settings.hasCompletedOnboarding {
                showOnboarding = true
            }
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch section ?? .history {
        case .history:
            HistoryListView(selection: $selectedRecordId)
        case .models:
            ModelManagementView()
        case .settings:
            EmptyStateView(
                systemImage: "gearshape",
                title: "Settings",
                subtitle: "Hotkey, permissions, model, and output options are in the pane to the right."
            )
        case .about:
            EmptyStateView(
                systemImage: "info.circle",
                title: "About",
                subtitle: "App info, credits, and links live in the detail pane."
            )
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch section ?? .history {
        case .history:
            if let id = selectedRecordId,
               let record = appState.history.records.first(where: { $0.id == id }) {
                TranscriptDetailView(record: record)
            } else {
                DetailEmptyView()
            }
        case .models:
            EmptyStateView(
                systemImage: "info.circle",
                title: "Whisper models",
                subtitle: "Download, activate, or delete models in the list to the left."
            )
        case .settings:
            SettingsContent()
        case .about:
            AboutView()
        }
    }
}

private struct DetailEmptyView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "text.bubble",
            title: "Select a transcription",
            subtitle: "Pick an item from the list to read, edit, or re-paste it."
        )
    }
}

private struct AboutView: View {
    @EnvironmentObject var appState: AppState

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private var activeModel: String {
        appState.dictation.currentModelName
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                metaGrid
                Divider().padding(.horizontal, 40)
                acknowledgements
                Divider().padding(.horizontal, 40)
                links
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }

    private var header: some View {
        VStack(spacing: 12) {
            BrandMark(size: 56)
            Text("Voxly").displayStyle(34).foregroundColor(Theme.text)
            Text("Local speech-to-text via whisper.cpp")
                .font(Theme.mono(12))
                .foregroundColor(Theme.accentText)
        }
    }

    private var metaGrid: some View {
        VStack(spacing: 6) {
            MetaRow(label: "Version",       value: version)
            MetaRow(label: "Active model",  value: "ggml-\(activeModel).bin")
            MetaRow(label: "whisper.cpp",   value: "v1.8.1")
            MetaRow(label: "macOS",         value: osVersion)
            MetaRow(label: "Architecture",  value: "arm64 (Apple Silicon)")
        }
        .frame(maxWidth: 420)
    }

    private var acknowledgements: some View {
        VStack(spacing: 8) {
            Text("Built with")
                .displayStyle(16)
                .foregroundColor(Theme.text)
            VStack(alignment: .leading, spacing: 4) {
                AckRow(name: "whisper.cpp", detail: "Georgi Gerganov - local Whisper inference (MIT)")
                AckRow(name: "ggml",        detail: "ML tensor library used by whisper.cpp (MIT)")
                AckRow(name: "KeyboardShortcuts", detail: "Sindre Sorhus - global hotkey handling (MIT)")
                AckRow(name: "Apple Accelerate / Metal", detail: "vDSP + GPU kernels for inference speed")
            }
        }
        .frame(maxWidth: 480)
    }

    private var links: some View {
        VStack(spacing: 10) {
            LinkButton(title: "Source on GitHub", url: "https://github.com/cengizhankose/Voxly")
            LinkButton(title: "whisper.cpp",      url: "https://github.com/ggerganov/whisper.cpp")
            LinkButton(title: "Report an issue",  url: "https://github.com/cengizhankose/Voxly/issues")

            Text("© 2026 Voxly. MIT License. All transcription happens on-device. Your audio never leaves this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .frame(maxWidth: 460)
        }
    }
}

private struct MetaRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(Theme.muted)
            Spacer()
            Text(value)
                .font(Theme.mono(12))
                .foregroundColor(Theme.text)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}

private struct AckRow: View {
    let name: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name).bold().foregroundColor(Theme.text)
            Text(detail).foregroundColor(Theme.muted)
        }
        .font(.callout)
    }
}

private struct LinkButton: View {
    let title: String
    let url: String

    var body: some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.square")
                Text(title)
            }
        }
        .buttonStyle(.link)
    }
}

/// Hand-rolled empty-state because `ContentUnavailableView` is macOS 14+.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Theme.muted)
            Text(title).displayStyle(22).foregroundColor(Theme.text)
            Text(subtitle)
                .font(.system(size: 13.5))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}
