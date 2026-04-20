import Foundation

enum RecognitionBackend: String {
    case senseVoice = "sensevoice"
    case whisper = "whisper"
}

class RecognitionManager {
    private var senseVoice: SenseVoiceBridge?
    private var whisper: WhisperBridge?
    private let queue = DispatchQueue(label: "com.fengur.WindWhisper.recognition", qos: .userInitiated)

    init() {
        loadModels()
    }

    private func loadModels() {
        if let dir = Bundle.main.path(forResource: "sensevoice", ofType: nil) {
            senseVoice = SenseVoiceBridge(modelDir: dir)
        }

        let whisperModels = ["ggml-small", "ggml-medium", "ggml-base"]
        for name in whisperModels {
            if let path = Bundle.main.path(forResource: name, ofType: "bin") {
                whisper = WhisperBridge(modelPath: path)
                Log.info("Whisper model loaded: \(name)")
                break
            }
        }

        if senseVoice == nil && whisper == nil {
            Log.error("No recognition model found")
        }
    }

    static var currentBackend: RecognitionBackend {
        let raw = UserDefaults.standard.string(forKey: "recognition.backend") ?? "sensevoice"
        return RecognitionBackend(rawValue: raw) ?? .senseVoice
    }

    static var currentLanguage: String {
        UserDefaults.standard.string(forKey: "whisper.language") ?? "zh"
    }

    func transcribe(pcmData: [Float]) -> String {
        switch Self.currentBackend {
        case .senseVoice:
            if let sv = senseVoice {
                return TextPostProcessor.process(sv.transcribe(pcmData: pcmData))
            }
            fallthrough
        case .whisper:
            if let w = whisper {
                return TextPostProcessor.process(w.transcribe(pcmData: pcmData, language: Self.currentLanguage))
            }
            return ""
        }
    }

    func transcribeAsync(pcmData: [Float], completion: @escaping (String) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion("") }
                return
            }
            let text = self.transcribe(pcmData: pcmData)
            DispatchQueue.main.async { completion(text) }
        }
    }

    var hasModel: Bool {
        senseVoice != nil || whisper != nil
    }

    var activeBackendName: String {
        switch Self.currentBackend {
        case .senseVoice: return senseVoice != nil ? "SenseVoice" : "Whisper (fallback)"
        case .whisper: return whisper != nil ? "Whisper" : "无可用模型"
        }
    }
}
