import Foundation

/// Centralised lookups for on-disk locations Voxly owns.
enum AppPaths {
    static func applicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let voxly = base.appendingPathComponent("Voxly", isDirectory: true)
        try? FileManager.default.createDirectory(at: voxly, withIntermediateDirectories: true)
        return voxly
    }

    static func historyFileURL() -> URL {
        applicationSupportDirectory().appendingPathComponent("history.json", isDirectory: false)
    }

    static func modelsDirectory() -> URL {
        let dir = applicationSupportDirectory().appendingPathComponent("models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
