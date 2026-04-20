import Cocoa
import SwiftUI

class FloatingPanelViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var isRecording: Bool = false
}

struct FloatingPanelView: View {
    @ObservedObject var viewModel: FloatingPanelViewModel

    var body: some View {
        HStack(spacing: 8) {
            if viewModel.isRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
            Text(viewModel.text.isEmpty ? " " : viewModel.text)
                .foregroundColor(.white)
                .font(.system(size: 14))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minWidth: 120, maxWidth: 400, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
        )
    }
}

class FloatingPanelController {
    private var panel: NSPanel?
    private let viewModel = FloatingPanelViewModel()

    func show() {
        if panel == nil {
            createPanel()
        }
        viewModel.isRecording = true
        viewModel.text = "正在聆听..."
        panel?.orderFrontRegardless()
    }

    func updateText(_ text: String) {
        viewModel.text = text
    }

    func showFinal(_ text: String, then completion: @escaping () -> Void) {
        viewModel.text = text
        viewModel.isRecording = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.hide()
            completion()
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 60),
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

        let hostingView = NSHostingView(rootView: FloatingPanelView(viewModel: viewModel))
        panel.contentView = hostingView

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 200
            let y = screenFrame.minY + 120
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.panel = panel
    }
}
