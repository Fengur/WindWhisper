import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let voiceEngine = VoiceEngine.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            button.image = NSImage(systemSymbolName: "wind", accessibilityDescription: "WindWhisper")
            button.toolTip = "WindWhisper — 点击录音 / 右键菜单"
            button.target = self
            button.action = #selector(onLeftClick)
        }

        // 右键菜单通过 event monitor
        NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            if let button = self?.statusItem.button, button.hitTest(event.locationInWindow) != nil {
                self?.onRightClick()
                return nil
            }
            return event
        }

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

    @objc private func onLeftClick() {
        print("[WindWhisper] Left click → toggle")
        voiceEngine.toggle()
    }

    @objc private func onRightClick() {
        guard let button = statusItem.button else { return }
        showMenu(from: button)
    }

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        let stateText: String
        switch voiceEngine.state {
        case .idle: stateText = "就绪"
        case .recording: stateText = "录音中..."
        case .transcribing: stateText = "识别中..."
        }
        let stateItem = NSMenuItem(title: "状态: \(stateText)", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        if !voiceEngine.lastText.isEmpty {
            let lastItem = NSMenuItem(title: "上次: \(voiceEngine.lastText.prefix(30))", action: nil, keyEquivalent: "")
            lastItem.isEnabled = false
            menu.addItem(lastItem)
        }

        menu.addItem(NSMenuItem.separator())

        let toggleTitle = voiceEngine.state == .recording ? "停止录音" : "开始录音"
        menu.addItem(NSMenuItem(title: toggleTitle, action: #selector(toggleRecording), keyEquivalent: "r"))

        menu.addItem(NSMenuItem.separator())

        let hotkeyItem = NSMenuItem(title: "快捷键: Cmd+Opt+R", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 WindWhisper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil // 用完清掉，下次左键点击才不会弹菜单
    }

    @objc private func toggleRecording() {
        voiceEngine.toggle()
    }

    private func updateIcon(_ state: VoiceEngine.State) {
        let iconName: String
        let tooltip: String
        switch state {
        case .idle:
            iconName = "wind"
            tooltip = "WindWhisper — 点击录音"
        case .recording:
            iconName = "wind.circle.fill"
            tooltip = "WindWhisper — 录音中，点击停止"
        case .transcribing:
            iconName = "wind.snow"
            tooltip = "WindWhisper — 识别中..."
        }
        statusItem.button?.image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: "WindWhisper"
        )
        statusItem.button?.toolTip = tooltip
    }
}
