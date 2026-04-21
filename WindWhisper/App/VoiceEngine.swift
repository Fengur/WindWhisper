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
    private let injector = TextInjector()
    let widget = FloatingWidgetController()
    private var micvolGuard: OpaquePointer?
    private var maxDurationTimer: Timer?
    private let maxRecordingDuration: TimeInterval = 60

    static var autoPaste: Bool {
        UserDefaults.standard.object(forKey: "autoPaste") as? Bool ?? true
    }

    private init() {}

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

        do {
            let device = try MicvolBridge.defaultInputDevice()
            micvolGuard = try MicvolBridge.guardMaximize(deviceId: device.id)
        } catch {
            Log.error("micvol: \(error), continuing without volume boost")
        }

        recorder.start()
        widget.startRecording()

        maxDurationTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
            Log.info("Max recording duration reached (\(self?.maxRecordingDuration ?? 0)s)")
            self?.stopRecording()
        }
    }

    private func stopRecording() {
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil

        let pcmBuffer = recorder.stop()

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
            Log.info("Recognition done (\(elapsed)s): \(text)")
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
