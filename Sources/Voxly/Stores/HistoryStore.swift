import Foundation
import Combine
import os

private let log = Logger(subsystem: "com.voxly.app", category: "HistoryStore")

/// JSON-backed transcription history. Loads synchronously on init, persists with a
/// debounced atomic write so rapid edits/append bursts don't thrash the disk.
@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [TranscriptionRecord] = []

    /// 0 means "forever". Records older than this are purged on load + on append.
    var retentionDays: Int = 0 {
        didSet { purgeIfNeeded() }
    }

    private let fileURL: URL
    private var saveWorkItem: DispatchWorkItem?

    init(fileURL: URL = AppPaths.historyFileURL()) {
        self.fileURL = fileURL
        load()
    }

    // MARK: mutations

    func append(_ record: TranscriptionRecord) {
        records.insert(record, at: 0) // newest first
        purgeIfNeeded()
        scheduleSave()
    }

    func update(_ record: TranscriptionRecord) {
        guard let idx = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[idx] = record
        scheduleSave()
    }

    func delete(_ record: TranscriptionRecord) {
        records.removeAll { $0.id == record.id }
        scheduleSave()
    }

    func delete(ids: Set<TranscriptionRecord.ID>) {
        records.removeAll { ids.contains($0.id) }
        scheduleSave()
    }

    func clearAll() {
        records.removeAll()
        scheduleSave()
    }

    // MARK: persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            log.info("No history file yet at: \(self.fileURL.path, privacy: .public)")
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = try decoder.decode([TranscriptionRecord].self, from: data)
            log.info("Loaded \(self.records.count) history records")
            purgeIfNeeded()
        } catch {
            log.error("Failed to load history: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = records
        let url = fileURL
        let item = DispatchWorkItem {
            Self.write(snapshot, to: url)
        }
        saveWorkItem = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    /// Synchronous flush — call before app termination if needed.
    func saveNow() {
        saveWorkItem?.cancel()
        Self.write(records, to: fileURL)
    }

    private static func write(_ snapshot: [TranscriptionRecord], to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
            log.debug("Wrote \(snapshot.count) records to disk")
        } catch {
            log.error("Failed to write history: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: retention

    private func purgeIfNeeded() {
        guard retentionDays > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86_400)
        let before = records.count
        records.removeAll { $0.createdAt < cutoff }
        if records.count != before {
            log.info("Purged \(before - self.records.count) records older than \(self.retentionDays)d")
        }
    }
}
