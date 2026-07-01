import Foundation

/// Static metadata for every Whisper model size Voxly knows how to download.
/// URLs point at the upstream Hugging Face mirror; expected bytes are used for
/// progress UX + disk-space precheck. Hashes intentionally omitted — TLS to
/// Hugging Face is treated as sufficient for v1.
struct ModelCatalogEntry {
    let size: ModelSize
    let remoteURL: URL
    let approximateBytes: Int64
}

enum ModelCatalog {
    static let entries: [ModelSize: ModelCatalogEntry] = [
        .tiny:   .init(size: .tiny,
                      remoteURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin")!,
                      approximateBytes:    77_700_000),
        .base:   .init(size: .base,
                      remoteURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!,
                      approximateBytes:   147_951_465),
        .small:  .init(size: .small,
                      remoteURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!,
                      approximateBytes:   487_000_000),
        .medium: .init(size: .medium,
                      remoteURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin")!,
                      approximateBytes: 1_533_000_000),
        .large:  .init(size: .large,
                      remoteURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin")!,
                      approximateBytes: 3_094_000_000),
    ]

    static func entry(for size: ModelSize) -> ModelCatalogEntry {
        entries[size]! // every ModelSize has an entry
    }
}
