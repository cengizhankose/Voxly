import SwiftUI

struct HistoryListView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selection: TranscriptionRecord.ID?
    @State private var query = ""

    private var filtered: [TranscriptionRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return appState.history.records }
        return appState.history.records.filter {
            $0.text.localizedCaseInsensitiveContains(trimmed) ||
            ($0.targetAppName ?? "").localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if appState.history.records.isEmpty {
                EmptyHistoryView()
            } else {
                List(selection: $selection) {
                    ForEach(filtered) { record in
                        HistoryRow(record: record)
                            .tag(record.id)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { filtered[$0].id }
                        appState.history.delete(ids: Set(ids))
                    }
                }
                .searchable(text: $query, placement: .sidebar, prompt: "Search transcripts")
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        appState.history.clearAll()
                    } label: {
                        Label("Clear All History", systemImage: "trash")
                    }
                    .disabled(appState.history.records.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let record: TranscriptionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.text)
                .lineLimit(2)
                .font(.system(size: 13))
                .foregroundColor(Theme.text)
            HStack(spacing: 6) {
                // Refresh the relative timestamp at 30s cadence rather than
                // SwiftUI's default 1s ticking — saves redraws and stops the
                // distracting second-by-second crawl.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(Self.relativeString(for: record.createdAt, now: context.date))
                }
                if let app = record.targetAppName {
                    Text("·")
                    Text(app)
                }
                Text("·")
                Text(formattedDuration(record.durationSeconds))
            }
            .font(Theme.mono(10.5))
            .foregroundColor(Theme.muted)
        }
        .padding(.vertical, 2)
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return s < 60 ? "\(s)s" : "\(s / 60)m \(s % 60)s"
    }

    /// Coarse minute/hour/day buckets. Sub-minute resolves to "Just now"
    /// instead of leaking seconds.
    private static func relativeString(for date: Date, now: Date) -> String {
        let interval = max(0, now.timeIntervalSince(date))
        if interval < 60 { return "Just now" }
        if interval < 3_600 { return "\(Int(interval / 60))m ago" }
        if interval < 86_400 { return "\(Int(interval / 3_600))h ago" }
        if interval < 86_400 * 7 { return "\(Int(interval / 86_400))d ago" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}

private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Theme.muted)
            Text("No transcriptions yet")
                .displayStyle(20)
                .foregroundColor(Theme.text)
            Text("Press Option+D anywhere to dictate.")
                .font(.system(size: 13.5))
                .foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}
