import Foundation

/// whisper.cpp C API 的 Swift 封装。
class WhisperBridge {
    private var ctx: OpaquePointer?

    init?(modelPath: String) {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            print("[WhisperBridge] Model not found: \(modelPath)")
            return nil
        }

        var cparams = whisper_context_default_params()
        ctx = whisper_init_from_file_with_params(modelPath, cparams)

        guard ctx != nil else {
            print("[WhisperBridge] Failed to load model")
            return nil
        }
        print("[WhisperBridge] Model loaded: \(modelPath)")
    }

    deinit {
        if let ctx {
            whisper_free(ctx)
        }
    }

    /// 识别 PCM Float32 数据（16kHz mono），返回文本。
    func transcribe(pcmData: [Float], language: String = "zh") -> String {
        guard let ctx, !pcmData.isEmpty else { return "" }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.no_timestamps = true
        params.single_segment = false

        // 设置语言
        let langCStr = language.withCString { strdup($0) }
        params.language = UnsafePointer(langCStr)

        let result = pcmData.withUnsafeBufferPointer { buffer in
            whisper_full(ctx, params, buffer.baseAddress, Int32(buffer.count))
        }

        free(langCStr)

        guard result == 0 else {
            print("[WhisperBridge] Transcription failed: \(result)")
            return ""
        }

        let nSegments = whisper_full_n_segments(ctx)
        var text = ""
        for i in 0..<nSegments {
            if let segText = whisper_full_get_segment_text(ctx, i) {
                text += String(cString: segText)
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
