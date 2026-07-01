import SwiftUI
import AppKit

struct TranscriptDetailView: View {
    @EnvironmentObject var appState: AppState
    let record: TranscriptionRecord

    @State private var editingText: String = ""
    @State private var didLoadForId: TranscriptionRecord.ID?
    @State private var showCopiedToast = false

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            metadataHeader
                .padding(.horizontal, 20)
                .padding(.top, 20)

            Divider()
                .padding(.vertical, 12)

            TextEditor(text: $editingText)
                .font(.system(size: 14))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 16)
                .scrollContentBackground(.hidden)

            Divider()

            actionBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                Text("Copied to clipboard")
                    .font(Theme.mono(11))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Theme.surface, in: Capsule())
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
        .background(Theme.bg)
        .onAppear { loadIfNeeded() }
        .onChange(of: record.id) { _ in loadIfNeeded() }
        .onChange(of: editingText) { newValue in
            // Persist edits as the user types (HistoryStore debounces the disk write).
            guard didLoadForId == record.id, newValue != record.text else { return }
            var updated = record
            updated.text = newValue
            appState.history.update(updated)
        }
    }

    private var metadataHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Self.dateFormatter.string(from: record.createdAt))
                    .displayStyle(17)
                    .foregroundColor(Theme.text)
                Spacer()
                Text(durationLabel)
                    .font(Theme.mono(12))
                    .foregroundColor(Theme.muted)
            }
            HStack(spacing: 6) {
                if let app = record.targetAppName {
                    Badge(text: app, systemImage: "app.dashed")
                }
                if let model = record.modelName {
                    Badge(text: model, systemImage: "cube")
                }
                if let lang = record.language {
                    Badge(text: lang, systemImage: "globe")
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                copy()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(GhostButtonStyle(compact: true))
            Button {
                pasteIntoLastApp()
            } label: {
                Label(pasteButtonLabel, systemImage: "arrow.up.right.square")
            }
            .buttonStyle(PrimaryButtonStyle(compact: true))
            .disabled(appState.dictation.lastExternalAppName == nil)
            Spacer()
            Button(role: .destructive) {
                appState.history.delete(record)
            } label: {
                Label("Delete", systemImage: "trash")
                    .foregroundColor(Theme.warning)
            }
            .buttonStyle(GhostButtonStyle(compact: true))
        }
    }

    private var pasteButtonLabel: String {
        if let name = appState.dictation.lastExternalAppName {
            return "Paste into \(name)"
        }
        return "Paste into Last App"
    }

    private var durationLabel: String {
        let s = Int(record.durationSeconds.rounded())
        return s < 60 ? "\(s)s" : "\(s / 60)m \(s % 60)s"
    }

    private func loadIfNeeded() {
        guard didLoadForId != record.id else { return }
        editingText = record.text
        didLoadForId = record.id
    }

    private func copy() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(editingText, forType: .string)
        flashCopied(pasted: false)
    }

    private func pasteIntoLastApp() {
        let pasted = appState.dictation.pasteFromHistory(
            editingText,
            accessibilityGranted: appState.accessibilityGranted
        )
        flashCopied(pasted: pasted)
    }

    private func flashCopied(pasted: Bool) {
        withAnimation(.easeInOut(duration: 0.15)) { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) { showCopiedToast = false }
        }
        _ = pasted // toast text is identical for now; kept for future differentiation
    }
}
