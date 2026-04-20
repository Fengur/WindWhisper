import Foundation

/// 管理 Whisper 模型加载和识别调度。
class WhisperManager {
    private var bridge: WhisperBridge?
    private let queue = DispatchQueue(label: "com.fengur.WindWhisper.whisper", qos: .userInitiated)

    init() {
        loadModel()
    }

    private func loadModel() {
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
        return bridge.transcribe(pcmData: pcmData, language: Self.currentLanguage)
    }

    static var currentLanguage: String {
        UserDefaults.standard.string(forKey: "whisper.language") ?? "zh"
    }

    func transcribeAsync(pcmData: [Float], completion: @escaping (String) -> Void) {
        let language = Self.currentLanguage
        queue.async { [weak self] in
            guard let self, let bridge = self.bridge else {
                DispatchQueue.main.async { completion("") }
                return
            }
            let text = bridge.transcribe(pcmData: pcmData, language: language)
            DispatchQueue.main.async { completion(text) }
        }
    }
}
