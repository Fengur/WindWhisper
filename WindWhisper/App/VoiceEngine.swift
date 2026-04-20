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
    private let panelController = FloatingPanelController()
    private var micvolGuard: OpaquePointer?
    private var interimTimer: Timer?
    private var isInterimInFlight = false

    private init() {}

    func toggle() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopAndTranscribe()
        case .transcribing:
            break
        }
    }

    private func startRecording() {
        setState(.recording)

        do {
            let device = try MicvolBridge.defaultInputDevice()
            micvolGuard = try MicvolBridge.guardMaximize(deviceId: device.id)
        } catch {
            print("[WindWhisper] micvol error: \(error), continuing without volume boost")
        }

        recorder.start()
        panelController.show()
        startInterimLoop()
    }

    private func startInterimLoop() {
        interimTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.runInterimTranscription()
        }
    }

    private func runInterimTranscription() {
        guard !isInterimInFlight else { return }

        let pcmSnapshot = recorder.snapshot()
        guard pcmSnapshot.count > 8000 else { return }

        isInterimInFlight = true
        whisper.transcribeAsync(pcmData: pcmSnapshot) { [weak self] text in
            guard let self else { return }
            self.isInterimInFlight = false
            if self.state == .recording && !text.isEmpty {
                self.panelController.updateText(text)
            }
        }
    }

    private func stopAndTranscribe() {
        interimTimer?.invalidate()
        interimTimer = nil

        let pcmBuffer = recorder.stop()

        if let guard_ = micvolGuard {
            try? MicvolBridge.guardRestore(guard_)
            micvolGuard = nil
        }

        setState(.transcribing)
        panelController.updateText("识别中...")

        whisper.transcribeAsync(pcmData: pcmBuffer) { [weak self] text in
            guard let self else { return }
            if !text.isEmpty {
                self.lastText = text
                self.panelController.showFinal(text) {
                    self.injector.inject(text: text)
                }
            } else {
                self.panelController.hide()
            }
            self.setState(.idle)
        }
    }

    private func setState(_ newState: State) {
        state = newState
        onStateChange?(newState)
    }
}
