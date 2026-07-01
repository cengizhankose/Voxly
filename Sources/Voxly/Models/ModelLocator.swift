import Foundation

/// Resolves where a whisper model lives on disk.
/// Bundle first (the only one shipped is `ggml-base.bin`), then user-installed
/// in `~/Library/Application Support/Voxly/models/`.
enum ModelLocator {
    /// Path for `size`, or nil if no file exists.
    static func path(for size: ModelSize) -> String? {
        if let bundled = Bundle.main.path(forResource: size.bundleResourceName, ofType: "bin") {
            return bundled
        }
        let userInstalled = AppPaths.modelsDirectory().appendingPathComponent(size.filename)
        if FileManager.default.fileExists(atPath: userInstalled.path) {
            return userInstalled.path
        }
        return nil
    }

    /// Sizes the user can pick today (file present on disk).
    static func availableSizes() -> Set<ModelSize> {
        Set(ModelSize.allCases.filter { path(for: $0) != nil })
    }
}
