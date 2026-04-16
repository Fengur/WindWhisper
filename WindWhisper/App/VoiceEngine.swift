import Foundation

/// 语音输入核心引擎，串联录音 → 识别 → 注入。
class VoiceEngine: ObservableObject {
    static let shared = VoiceEngine()

    enum State {
        case idle
        case recording
        case transcribing
    }

    @Published var state: State = .idle
    @Published var lastText: String = ""

    var onStateChange: ((State) -> Void)?

    private let recorder = AudioRecorder()
    private let whisper = WhisperManager()
    private let injector = TextInjector()
    private var micvolGuard: OpaquePointer?

    private init() {}

    func toggle() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopAndTranscribe()
        case .transcribing:
            break // 识别中不响应
        }
    }

    private func startRecording() {
        setState(.recording)

        // 拉满输入音量
        do {
            let device = try MicvolBridge.defaultInputDevice()
            micvolGuard = try MicvolBridge.guardMaximize(deviceId: device.id)
        } catch {
            print("[WindWhisper] micvol error: \(error), continuing without volume boost")
        }

        recorder.start()
    }

    private func stopAndTranscribe() {
        let pcmBuffer = recorder.stop()

        // 恢复音量
        if let guard_ = micvolGuard {
            try? MicvolBridge.guardRestore(guard_)
            micvolGuard = nil
        }

        setState(.transcribing)

        // 后台识别
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let text = self.whisper.transcribe(pcmData: pcmBuffer)

            DispatchQueue.main.async {
                if !text.isEmpty {
                    self.lastText = text
                    self.injector.inject(text: text)
                }
                self.setState(.idle)
            }
        }
    }

    private func setState(_ newState: State) {
        state = newState
        onStateChange?(newState)
    }
}
