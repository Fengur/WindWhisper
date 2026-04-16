import Foundation

/// 管理 Whisper 模型加载和识别调度。
class WhisperManager {
    private var bridge: WhisperBridge?

    init() {
        loadModel()
    }

    private func loadModel() {
        // 在 app bundle 的 Resources 目录查找模型
        if let path = Bundle.main.path(forResource: "ggml-base", ofType: "bin") {
            bridge = WhisperBridge(modelPath: path)
        } else {
            print("[WhisperManager] Model file not found in bundle, whisper disabled")
        }
    }

    func transcribe(pcmData: [Float]) -> String {
        guard let bridge else {
            return "[模型未加载]"
        }
        return bridge.transcribe(pcmData: pcmData)
    }
}
