import Cocoa
import SwiftUI

class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if let w = window, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.isReleasedWhenClosed = false
        w.title = "WindWhisper 设置"
        w.level = .floating
        w.center()
        w.contentView = NSHostingView(rootView: SettingsView())
        w.makeKeyAndOrderFront(nil)
        self.window = w

        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @State private var language: String = UserDefaults.standard.string(forKey: "whisper.language") ?? "zh"

    private let languageOptions: [(id: String, label: String)] = [
        ("zh", "中文"),
        ("en", "English"),
        ("auto", "自动检测"),
    ]

    @State private var showWidget: Bool = UserDefaults.standard.object(forKey: "widget.visible") as? Bool ?? true

    var body: some View {
        Form {
            HStack {
                Text("触发方式")
                Spacer()
                Text("双击 Fn 键 / 点击悬浮按钮")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("识别语言")
                Spacer()
                Picker("", selection: $language) {
                    ForEach(languageOptions, id: \.id) { option in
                        Text(option.label).tag(option.id)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
                .onChange(of: language) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "whisper.language")
                }
            }

            Toggle("显示悬浮按钮", isOn: $showWidget)
                .onChange(of: showWidget) { newValue in
                    if newValue {
                        VoiceEngine.shared.widget.show()
                    } else {
                        VoiceEngine.shared.widget.hide()
                    }
                }
        }
        .formStyle(.grouped)
        .frame(width: 320)

        HStack {
            Button("重置位置") {
                VoiceEngine.shared.widget.resetPosition()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}
