import Cocoa
import SwiftUI

class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "WindWhisper 设置"
        window.level = .floating
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView())
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @State private var config = HotkeyConfig.load()
    @State private var language: String = UserDefaults.standard.string(forKey: "whisper.language") ?? "zh"

    private let languageOptions: [(id: String, label: String)] = [
        ("zh", "中文"),
        ("en", "English"),
        ("auto", "自动检测"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("快捷键")
                    .frame(width: 60, alignment: .trailing)
                HotkeyRecorderView(config: $config)
                Spacer()
            }

            HStack {
                Text("语言")
                    .frame(width: 60, alignment: .trailing)
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
                Spacer()
            }

            HStack {
                Spacer()
                Button("恢复默认") {
                    config = .default
                    config.save()
                    HotkeyManager.shared.updateHotkey(config)
                    language = "zh"
                    UserDefaults.standard.set("zh", forKey: "whisper.language")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}

struct HotkeyRecorderView: View {
    @Binding var config: HotkeyConfig
    @State private var isListening = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: { startListening() }) {
            Text(isListening ? "请按下快捷键..." : config.displayString)
                .frame(minWidth: 140)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .onDisappear { stopListening() }
    }

    private func startListening() {
        isListening = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopListening()
                return nil
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasModifier = !flags.intersection([.command, .option, .control, .shift]).isEmpty

            if hasModifier {
                config = HotkeyConfig(
                    keyCode: CGKeyCode(event.keyCode),
                    modifiers: HotkeyConfig.fromNSEventFlags(event.modifierFlags)
                )
                config.save()
                HotkeyManager.shared.updateHotkey(config)
                stopListening()
                return nil
            }
            return event
        }
    }

    private func stopListening() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isListening = false
    }
}
