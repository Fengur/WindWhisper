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
    private let recognition = RecognitionManager()
    private var streamingRecognizer: StreamingRecognizer?
    private let injector = TextInjector()
    let widget = FloatingWidgetController()
    private var micvolGuard: OpaquePointer?
    private var streamingText: String = ""

    static var autoPaste: Bool {
        UserDefaults.standard.object(forKey: "autoPaste") as? Bool ?? true
    }

    private init() {
        if let dir = Bundle.main.path(forResource: "paraformer-streaming", ofType: nil) {
            streamingRecognizer = StreamingRecognizer(modelDir: dir)
        }
    }

    func toggle() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .transcribing:
            break
        }
    }

    private func startRecording() {
        setState(.recording)
        streamingText = ""

        do {
            let device = try MicvolBridge.defaultInputDevice()
            micvolGuard = try MicvolBridge.guardMaximize(deviceId: device.id)
        } catch {
            Log.error("micvol: \(error), continuing without volume boost")
        }

        streamingRecognizer?.reset()
        streamingRecognizer?.onResult = { [weak self] text, isEndpoint in
            guard let self, self.state == .recording else { return }
            self.streamingText = text
            self.widget.updateText(text)
            Log.info("Streaming: \(text.prefix(60))\(isEndpoint ? " [endpoint]" : "")")
        }

        recorder.onSamples = { [weak self] samples in
            self?.streamingRecognizer?.feedSamples(samples)
        }

        recorder.start()
        widget.startRecording()
    }

    private func stopRecording() {
        let pcmBuffer = recorder.stop()
        recorder.onSamples = nil
        streamingRecognizer?.reset()

        if let guard_ = micvolGuard {
            try? MicvolBridge.guardRestore(guard_)
            micvolGuard = nil
        }

        setState(.transcribing)
        widget.updateText("识别中...")

        let startTime = CFAbsoluteTimeGetCurrent()
        recognition.transcribeAsync(pcmData: pcmBuffer) { [weak self] text in
            guard let self else { return }
            let elapsed = String(format: "%.1f", CFAbsoluteTimeGetCurrent() - startTime)
            Log.info("Final recognition done (\(elapsed)s): \(text)")
            if !text.isEmpty {
                self.finishWithText(text)
            } else {
                self.widget.collapse()
                self.setState(.idle)
            }
        }
    }

    private func finishWithText(_ text: String) {
        lastText = text
        widget.showResult(text)
        if Self.autoPaste {
            injector.inject(text: text)
        }
        setState(.idle)
    }

    private func setState(_ newState: State) {
        state = newState
        onStateChange?(newState)
    }
}
