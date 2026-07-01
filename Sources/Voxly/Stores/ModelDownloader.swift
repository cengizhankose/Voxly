import Foundation
import Combine
import os

private let log = Logger(subsystem: "com.voxly.app", category: "ModelDownloader")

enum ModelDownloadStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double, bytesWritten: Int64, totalBytes: Int64)
    case available
    case failed(message: String)

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
}

/// Manages whisper model downloads. Single concurrent download; further calls
/// are rejected while one is in-flight. Foreground URLSession (cancels if app
/// quits — acceptable v1 trade-off for simplicity).
@MainActor
final class ModelDownloader: NSObject, ObservableObject {
    /// Per-model status. Re-derived from disk on init and after each completion.
    @Published private(set) var statuses: [ModelSize: ModelDownloadStatus] = [:]

    private var activeTask: URLSessionDownloadTask?
    private var activeSize: ModelSize?
    private var session: URLSession!

    /// Bundled `ggml-base.bin` always reports `.available` even when no copy exists
    /// in `~/Library/Application Support/Voxly/models/`.
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        // Background-task-like leniency without the lifetime guarantees.
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60 * 60 * 4 // 4h cap for large model
        config.waitsForConnectivity = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        refreshStatuses()
    }

    func refreshStatuses() {
        var next: [ModelSize: ModelDownloadStatus] = [:]
        for size in ModelSize.allCases {
            if let current = statuses[size], current.isDownloading {
                next[size] = current
            } else if ModelLocator.path(for: size) != nil {
                next[size] = .available
            } else {
                next[size] = .notDownloaded
            }
        }
        statuses = next
    }

    func startDownload(_ size: ModelSize) {
        guard activeTask == nil else {
            log.warning("Refusing concurrent download — \(self.activeSize?.rawValue ?? "?", privacy: .public) is in flight")
            return
        }
        if case .available = statuses[size] {
            log.info("\(size.rawValue, privacy: .public) already available")
            return
        }
        let entry = ModelCatalog.entry(for: size)
        guard hasEnoughFreeSpace(for: entry.approximateBytes) else {
            statuses[size] = .failed(message: "Not enough free disk space")
            log.error("Insufficient disk space for \(size.rawValue, privacy: .public)")
            return
        }

        let task = session.downloadTask(with: entry.remoteURL)
        task.countOfBytesClientExpectsToReceive = entry.approximateBytes
        activeTask = task
        activeSize = size
        statuses[size] = .downloading(progress: 0, bytesWritten: 0, totalBytes: entry.approximateBytes)
        task.resume()
        log.info("Started download for \(size.rawValue, privacy: .public)")
    }

    func cancelDownload() {
        guard let task = activeTask, let size = activeSize else { return }
        task.cancel()
        statuses[size] = .notDownloaded
        activeTask = nil
        activeSize = nil
        log.info("Cancelled download for \(size.rawValue, privacy: .public)")
    }

    func deleteDownloaded(_ size: ModelSize) -> Bool {
        // Refuse to delete the bundled base.bin (lives inside the .app, not in
        // Application Support). `ModelLocator.path(for: .base)` returns the
        // bundle path when nothing's in models/; checking that distinguishes.
        let userInstalled = AppPaths.modelsDirectory().appendingPathComponent(size.filename)
        guard FileManager.default.fileExists(atPath: userInstalled.path) else {
            log.info("No user-installed copy of \(size.rawValue, privacy: .public) to delete")
            refreshStatuses()
            return false
        }
        do {
            try FileManager.default.removeItem(at: userInstalled)
            log.info("Deleted \(userInstalled.lastPathComponent, privacy: .public)")
            refreshStatuses()
            return true
        } catch {
            log.error("Delete failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: helpers

    private func hasEnoughFreeSpace(for bytes: Int64) -> Bool {
        let url = AppPaths.modelsDirectory()
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let available = values.volumeAvailableCapacityForImportantUsage else {
            return true // fall through if we can't tell
        }
        // 1.5x headroom — the file is downloaded to a tmp location first.
        return available > Int64(Double(bytes) * 1.5)
    }
}

// MARK: URLSessionDownloadDelegate

extension ModelDownloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let total = max(totalBytesExpectedToWrite, 1)
        let progress = Double(totalBytesWritten) / Double(total)
        Task { @MainActor in
            guard let size = activeSize else { return }
            statuses[size] = .downloading(
                progress: progress,
                bytesWritten: totalBytesWritten,
                totalBytes: total
            )
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Must move synchronously here — `location` is deleted after this method returns.
        let size = MainActor.assumeIsolated { self.activeSize }
        guard let size else { return }

        let dest = AppPaths.modelsDirectory().appendingPathComponent(size.filename)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: location, to: dest)
            log.info("Saved \(dest.lastPathComponent, privacy: .public)")
            Task { @MainActor in
                self.activeTask = nil
                self.activeSize = nil
                self.refreshStatuses()
            }
        } catch {
            log.error("Move failed: \(error.localizedDescription, privacy: .public)")
            Task { @MainActor in
                self.statuses[size] = .failed(message: "Failed to save: \(error.localizedDescription)")
                self.activeTask = nil
                self.activeSize = nil
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error else { return }
        // CancelledError = user-initiated, already cleared in cancelDownload.
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }
        Task { @MainActor in
            guard let size = activeSize else { return }
            statuses[size] = .failed(message: error.localizedDescription)
            activeTask = nil
            activeSize = nil
            log.error("Download failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
