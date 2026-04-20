import Foundation

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
    let widget = FloatingWidgetController()
    private var micvolGuard: OpaquePointer?
    private var interimTimer: Timer?
    private var isInterimInFlight = false

    static var autoPaste: Bool {
        UserDefaults.standard.object(forKey: "autoPaste") as? Bool ?? true
    }

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
            Log.error("micvol: \(error), continuing without volume boost")
        }

        recorder.start()
        widget.startRecording()
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
        guard pcmSnapshot.count > 24000 else { return }

        let audioDuration = String(format: "%.1f", Double(pcmSnapshot.count) / 16000.0)
        Log.info("Interim transcription start (\(audioDuration)s audio)")

        isInterimInFlight = true
        let startTime = CFAbsoluteTimeGetCurrent()
        whisper.transcribeAsync(pcmData: pcmSnapshot) { [weak self] text in
            guard let self else { return }
            let elapsed = String(format: "%.1f", CFAbsoluteTimeGetCurrent() - startTime)
            Log.info("Interim transcription done (\(elapsed)s): \(text.prefix(50))")
            self.isInterimInFlight = false
            if self.state == .recording && !text.isEmpty {
                self.widget.updateText(text)
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
        widget.updateText("识别中...")

        let audioDuration = String(format: "%.1f", Double(pcmBuffer.count) / 16000.0)
        Log.info("Final transcription start (\(audioDuration)s audio)")
        let startTime = CFAbsoluteTimeGetCurrent()
        whisper.transcribeAsync(pcmData: pcmBuffer) { [weak self] text in
            guard let self else { return }
            let elapsed = String(format: "%.1f", CFAbsoluteTimeGetCurrent() - startTime)
            Log.info("Final transcription done (\(elapsed)s): \(text)")
            if !text.isEmpty {
                self.lastText = text
                self.widget.showResult(text)
                if Self.autoPaste {
                    self.injector.inject(text: text)
                }
            } else {
                self.widget.collapse()
            }
            self.setState(.idle)
        }
    }

    private func setState(_ newState: State) {
        state = newState
        onStateChange?(newState)
    }
}
