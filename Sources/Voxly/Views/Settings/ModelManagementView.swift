import SwiftUI
import AppKit

/// Whisper-model management UI shared between the Settings `Model` tab and
/// the main window's `Models` sidebar section.
struct ModelManagementView: View {
    var body: some View {
        Form {
            Section {
                ForEach(ModelSize.allCases) { size in
                    ModelRow(size: size)
                }
            } header: {
                Text("Whisper models")
            } footer: {
                Text("Larger models are more accurate but slower and use more memory. Only one model is active at a time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Storage") {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([AppPaths.modelsDirectory()])
                } label: {
                    Label("Reveal Models Folder", systemImage: "folder")
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ModelRow: View {
    @EnvironmentObject var appState: AppState
    let size: ModelSize

    private var status: ModelDownloadStatus {
        appState.downloader.statuses[size] ?? .notDownloaded
    }

    private var isActive: Bool {
        appState.settings.selectedModelSize == size && appState.dictation.currentModelName == size.rawValue
    }

    private var isUserInstalled: Bool {
        FileManager.default.fileExists(atPath: AppPaths.modelsDirectory().appendingPathComponent(size.filename).path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                Text(size.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.text)
                Spacer()
                actionButtons
            }
            if case .downloading(let p, let written, let total) = status {
                ProgressView(value: p)
                Text("\(formatBytes(written)) / \(formatBytes(total))  ·  \(Int(p * 100))%")
                    .font(Theme.mono(10.5))
                    .foregroundColor(Theme.muted)
            }
            if case .failed(let msg) = status {
                Text(msg)
                    .font(Theme.mono(10.5))
                    .foregroundColor(Theme.warning)
            }
            if isActive {
                Badge(text: "Active model", accent: true, dot: true)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch status {
        case .available:
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.positive)
            } else {
                Button("Use") { activate() }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
            }
            if isUserInstalled {
                Button(role: .destructive) {
                    _ = appState.downloader.deleteDownloaded(size)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(Theme.warning)
                }
                .buttonStyle(.plain)
                .help("Delete downloaded copy")
            }
        case .notDownloaded:
            Button("Download") { appState.downloader.startDownload(size) }
                .buttonStyle(PrimaryButtonStyle(compact: true))
                .disabled(anyDownloadInFlight)
        case .downloading:
            Button("Cancel") { appState.downloader.cancelDownload() }
                .buttonStyle(GhostButtonStyle(compact: true))
        case .failed:
            Button("Retry") { appState.downloader.startDownload(size) }
                .buttonStyle(PrimaryButtonStyle(compact: true))
                .disabled(anyDownloadInFlight)
        }
    }

    private var anyDownloadInFlight: Bool {
        appState.downloader.statuses.values.contains(where: \.isDownloading)
    }

    private var iconName: String {
        switch status {
        case .available:    return isActive ? "checkmark.circle.fill" : "cube.box.fill"
        case .downloading:  return "arrow.down.circle"
        case .failed:       return "exclamationmark.triangle.fill"
        case .notDownloaded: return "cube.box"
        }
    }

    private var iconColor: Color {
        switch status {
        case .available where isActive: return Theme.positive
        case .available:                return Theme.accentText
        case .downloading:              return Theme.accentText
        case .failed:                   return Theme.warning
        case .notDownloaded:            return Theme.muted
        }
    }

    private func activate() {
        appState.settings.selectedModelSize = size
    }

    private func formatBytes(_ b: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: b)
    }
}
