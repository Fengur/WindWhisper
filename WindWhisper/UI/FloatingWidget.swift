import Cocoa
import SwiftUI

// MARK: - ViewModel

enum WidgetState {
    case idle
    case recording
    case transcribing
}

class FloatingWidgetViewModel: ObservableObject {
    @Published var state: WidgetState = .idle
    @Published var text: String = ""
    var onToggle: (() -> Void)?
}

// MARK: - SwiftUI View

struct FloatingWidgetView: View {
    @ObservedObject var viewModel: FloatingWidgetViewModel
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 0) {
            button
            if viewModel.state != .idle {
                textPanel
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .background(background)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.state)
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
    }

    private var button: some View {
        ZStack {
            Circle()
                .fill(buttonColor)
                .frame(width: 44, height: 44)
                .scaleEffect(pulseScale)

            Image(systemName: buttonIcon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(width: 48, height: 48)
        .contentShape(Circle())
        .onTapGesture { viewModel.onToggle?() }
        .onChange(of: viewModel.state) { newState in
            if newState == .recording {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    pulseScale = 1.0
                }
            }
        }
    }

    private var textPanel: some View {
        Text(viewModel.text.isEmpty ? " " : viewModel.text)
            .font(.system(size: 13))
            .foregroundColor(.primary)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 340, alignment: .leading)
            .padding(.leading, 4)
            .padding(.trailing, 14)
            .padding(.vertical, 10)
    }

    private var background: some View {
        Capsule()
            .fill(.ultraThinMaterial)
    }

    private var buttonColor: Color {
        switch viewModel.state {
        case .idle: return Color.gray.opacity(0.6)
        case .recording: return .red
        case .transcribing: return .orange
        }
    }

    private var buttonIcon: String {
        switch viewModel.state {
        case .idle: return "wind"
        case .recording: return "waveform"
        case .transcribing: return "ellipsis"
        }
    }
}

// MARK: - Controller

class FloatingWidgetController {
    private var panel: NSPanel?
    private let viewModel = FloatingWidgetViewModel()

    private static let posXKey = "widget.posX"
    private static let posYKey = "widget.posY"

    func setup(onToggle: @escaping () -> Void) {
        viewModel.onToggle = onToggle
        createPanel()
    }

    func startRecording() {
        viewModel.text = "正在聆听..."
        viewModel.state = .recording
        updatePanelSize()
    }

    func updateText(_ text: String) {
        viewModel.text = text
        updatePanelSize()
    }

    func showFinal(_ text: String, then completion: @escaping () -> Void) {
        viewModel.text = text
        viewModel.state = .transcribing
        updatePanelSize()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            completion()
            self?.viewModel.state = .idle
            self?.viewModel.text = ""
            self?.updatePanelSize()
        }
    }

    func resetPosition() {
        UserDefaults.standard.removeObject(forKey: Self.posXKey)
        UserDefaults.standard.removeObject(forKey: Self.posYKey)
        positionPanel()
    }

    // MARK: - Panel

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 48, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hasShadow = false

        let hostingView = NSHostingView(rootView: FloatingWidgetView(viewModel: viewModel))
        hostingView.frame = panel.contentRect(forFrameRect: panel.frame)
        panel.contentView = hostingView

        positionPanel()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.savePosition()
        }

        self.panel = panel
    }

    private func positionPanel() {
        guard let panel else { return }

        if let x = UserDefaults.standard.object(forKey: Self.posXKey) as? CGFloat,
           let y = UserDefaults.standard.object(forKey: Self.posYKey) as? CGFloat {
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 70
            let y = screen.visibleFrame.midY
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    private func savePosition() {
        guard let panel else { return }
        UserDefaults.standard.set(panel.frame.origin.x, forKey: Self.posXKey)
        UserDefaults.standard.set(panel.frame.origin.y, forKey: Self.posYKey)
    }

    private func updatePanelSize() {
        guard let panel, let hostingView = panel.contentView as? NSHostingView<FloatingWidgetView> else { return }

        let fittingSize = hostingView.fittingSize
        let origin = panel.frame.origin
        let newFrame = NSRect(origin: origin, size: fittingSize)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }
    }
}
