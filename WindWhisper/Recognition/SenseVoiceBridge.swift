import Foundation

class SenseVoiceBridge {
    private var recognizer: SherpaOnnxOfflineRecognizer?

    init?(modelDir: String) {
        let modelPath = (modelDir as NSString).appendingPathComponent("model.int8.onnx")
        let tokensPath = (modelDir as NSString).appendingPathComponent("tokens.txt")

        guard FileManager.default.fileExists(atPath: modelPath) else {
            Log.error("SenseVoice model not found: \(modelPath)")
            return nil
        }

        let senseVoiceConfig = sherpaOnnxOfflineSenseVoiceModelConfig(
            model: modelPath,
            language: "auto",
            useInverseTextNormalization: true
        )

        let modelConfig = sherpaOnnxOfflineModelConfig(
            tokens: tokensPath,
            numThreads: 2,
            debug: 0,
            senseVoice: senseVoiceConfig
        )

        let featConfig = sherpaOnnxFeatureConfig(
            sampleRate: 16000,
            featureDim: 80
        )

        var config = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig
        )

        recognizer = SherpaOnnxOfflineRecognizer(config: &config)
        Log.info("SenseVoice model loaded from \(modelDir)")
    }

    func transcribe(pcmData: [Float]) -> String {
        guard let recognizer, !pcmData.isEmpty else { return "" }
        let result = recognizer.decode(samples: pcmData, sampleRate: 16000)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
