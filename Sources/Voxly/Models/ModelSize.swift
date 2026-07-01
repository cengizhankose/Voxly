import Foundation

enum ModelSize: String, Codable, CaseIterable, Identifiable {
    case tiny
    case base
    case small
    case medium
    case large

    var id: String { rawValue }

    /// Filename pattern used both by the bundled model and downloaded models.
    var filename: String { "ggml-\(rawValue).bin" }

    /// Whisper resource basename without extension (used by `Bundle.path(forResource:)`).
    var bundleResourceName: String { "ggml-\(rawValue)" }

    var displayName: String {
        switch self {
        case .tiny:   return "Tiny (~75 MB)"
        case .base:   return "Base (~142 MB)"
        case .small:  return "Small (~466 MB)"
        case .medium: return "Medium (~1.5 GB)"
        case .large:  return "Large (~2.9 GB)"
        }
    }
}
