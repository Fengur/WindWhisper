import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let voiceEngine = VoiceEngine.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        HotkeyManager.shared.register { [weak self] in
            self?.voiceEngine.toggle()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "WindWhisper")
            button.action = #selector(onStatusItemClick)
            button.target = self
        }

        // 监听录音状态变化，更新图标
        voiceEngine.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.updateIcon(state)
            }
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: StatusBarView(engine: voiceEngine)
        )
    }

    @objc private func onStatusItemClick() {
        guard let button = statusItem.button else { return }

        if NSEvent.modifierFlags.contains(.option) {
            // Option + 点击 = 打开面板
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        } else {
            // 普通点击 = 切换录音
            voiceEngine.toggle()
        }
    }

    private func updateIcon(_ state: VoiceEngine.State) {
        let iconName: String
        switch state {
        case .idle:
            iconName = "mic"
        case .recording:
            iconName = "mic.fill"
        case .transcribing:
            iconName = "ellipsis.circle"
        }
        statusItem.button?.image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: "WindWhisper"
        )
    }
}
