import SwiftUI

struct StatusBarView: View {
    @ObservedObject var engine: VoiceEngine

    var body: some View {
        VStack(spacing: 16) {
            // 状态指示
            HStack {
                Circle()
                    .fill(stateColor)
                    .frame(width: 10, height: 10)
                Text(stateText)
                    .font(.headline)
            }

            // 上次识别的文本
            if !engine.lastText.isEmpty {
                Text(engine.lastText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
            }

            Divider()

            // 操作按钮
            Button(action: { engine.toggle() }) {
                HStack {
                    Image(systemName: engine.state == .recording ? "stop.fill" : "mic.fill")
                    Text(engine.state == .recording ? "停止" : "开始录音")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(engine.state == .recording ? .red : .blue)
            .disabled(engine.state == .transcribing)

            // 快捷键提示
            Text("Cmd + Opt + R")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Button("退出 WindWhisper") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 260)
    }

    private var stateColor: Color {
        switch engine.state {
        case .idle: return .green
        case .recording: return .red
        case .transcribing: return .orange
        }
    }

    private var stateText: String {
        switch engine.state {
        case .idle: return "就绪"
        case .recording: return "录音中..."
        case .transcribing: return "识别中..."
        }
    }
}
