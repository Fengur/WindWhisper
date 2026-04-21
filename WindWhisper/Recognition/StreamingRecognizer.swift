import Foundation

class StreamingRecognizer {
    private var recognizer: SherpaOnnxRecognizer?
    private let queue = DispatchQueue(label: "com.fengur.WindWhisper.streaming", qos: .userInitiated)
    var onResult: ((String, Bool) -> Void)?

    init?(modelDir: String) {
        let encoderPath = (modelDir as NSString).appendingPathComponent("encoder.int8.onnx")
        let decoderPath = (modelDir as NSString).appendingPathComponent("decoder.int8.onnx")
        let tokensPath = (modelDir as NSString).appendingPathComponent("tokens.txt")

        guard FileManager.default.fileExists(atPath: encoderPath) else {
            Log.error("StreamingRecognizer: encoder not found at \(encoderPath)")
            return nil
        }

        let paraformerConfig = sherpaOnnxOnlineParaformerModelConfig(
            encoder: encoderPath,
            decoder: decoderPath
        )

        let modelConfig = sherpaOnnxOnlineModelConfig(
            tokens: tokensPath,
            paraformer: paraformerConfig,
            numThreads: 2,
            debug: 0
        )

        let featConfig = sherpaOnnxFeatureConfig(
            sampleRate: 16000,
            featureDim: 80
        )

        var config = sherpaOnnxOnlineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig
        )

        recognizer = SherpaOnnxRecognizer(config: &config)
        Log.info("StreamingRecognizer: loaded from \(modelDir)")
    }

    func feedSamples(_ samples: [Float]) {
        queue.async { [weak self] in
            guard let self, let recognizer = self.recognizer else { return }
            recognizer.acceptWaveform(samples: samples)

            while recognizer.isReady() {
                recognizer.decode()
            }

            let result = recognizer.getResult()
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let isEndpoint = recognizer.isEndpoint()

            if isEndpoint {
                recognizer.reset()
            }

            if !text.isEmpty {
                DispatchQueue.main.async {
                    self.onResult?(TextPostProcessor.process(text), isEndpoint)
                }
            }
        }
    }

    func reset() {
        queue.async { [weak self] in
            self?.recognizer?.reset()
        }
    }
}
