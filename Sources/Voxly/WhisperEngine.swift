import Foundation

actor WhisperEngine {
    private var context: OpaquePointer?

    func loadModel(path: String) -> Bool {
        let params = whisper_context_default_params()
        context = whisper_init_from_file_with_params(path, params)
        return context != nil
    }

    func transcribe(audioData: [Float]) -> String {
        guard let ctx = context else { return "" }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.print_realtime = false
        params.single_segment = false
        params.no_context = true
        params.language = nil // auto-detect
        params.n_threads = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 2))

        let result = audioData.withUnsafeBufferPointer { bufferPtr -> Int32 in
            whisper_full(ctx, params, bufferPtr.baseAddress, Int32(audioData.count))
        }

        guard result == 0 else { return "" }

        let segmentCount = whisper_full_n_segments(ctx)
        var fullText = ""

        for i in 0..<segmentCount {
            if let cStr = whisper_full_get_segment_text(ctx, i) {
                fullText += String(cString: cStr)
            }
        }

        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    deinit {
        if let ctx = context {
            whisper_free(ctx)
        }
    }
}
