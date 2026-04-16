import AVFoundation

/// AVAudioEngine 录制 16kHz mono PCM。
class AudioRecorder {
    private var engine: AVAudioEngine?
    private var pcmBuffer: [Float] = []
    private let lock = NSLock()

    func start() {
        pcmBuffer = []
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // whisper.cpp 需要 16kHz mono Float32
        let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        let inputFormat = inputNode.outputFormat(forBus: 0)

        // 如果硬件采样率不同，需要转换
        let converter = AVAudioConverter(from: inputFormat, to: desiredFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let converter else { return }

            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * 16000.0 / inputFormat.sampleRate
            )
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: desiredFormat, frameCapacity: frameCount) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if status == .haveData, let channelData = convertedBuffer.floatChannelData?[0] {
                let count = Int(convertedBuffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: channelData, count: count))
                self.lock.lock()
                self.pcmBuffer.append(contentsOf: samples)
                self.lock.unlock()
            }
        }

        do {
            try engine.start()
            self.engine = engine
            print("[WindWhisper] Recording started")
        } catch {
            print("[WindWhisper] Failed to start recording: \(error)")
        }
    }

    /// 停止录音，返回 PCM 数据。
    func stop() -> [Float] {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil

        lock.lock()
        let result = pcmBuffer
        pcmBuffer = []
        lock.unlock()

        print("[WindWhisper] Recording stopped, \(result.count) samples (\(String(format: "%.1f", Double(result.count) / 16000.0))s)")
        return result
    }
}
