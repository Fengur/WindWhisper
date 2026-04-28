import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let voiceEngine = VoiceEngine.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        TextInjector.ensureAccessibility()
        setupStatusItem()
        setupPopover()

        voiceEngine.widget.setup { [weak self] in
            self?.voiceEngine.toggle()
        }

    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(named: "icon_statusbar") {
                img.size = NSSize(width: 18, height: 18)
                // 沿用设计师彩色版,不走 template 自动染色
                img.isTemplate = false
                button.image = img
            }
            button.toolTip = "WindWhisper — 点击录音 / 右键菜单"
            button.target = self
            button.action = #selector(onLeftClick)
        }

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
        Log.info("Left click → toggle")
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
        menu.addItem(NSMenuItem(title: toggleTitle, action: #selector(toggleRecording), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        let recoverItem = NSMenuItem(title: "显示悬浮球 (重置位置)", action: #selector(recoverWidget), keyEquivalent: "")
        recoverItem.target = self
        menu.addItem(recoverItem)

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 WindWhisper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleRecording() {
        voiceEngine.toggle()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func recoverWidget() {
        voiceEngine.widget.resetPosition()
        voiceEngine.widget.show()
    }

    private func updateIcon(_ state: VoiceEngine.State) {
        let tooltip: String
        switch state {
        case .idle:
            tooltip = "WindWhisper — 点击录音"
            statusItem.button?.contentTintColor = nil
        case .recording:
            tooltip = "WindWhisper — 录音中，点击停止"
            statusItem.button?.contentTintColor = .systemRed
        case .transcribing:
            tooltip = "WindWhisper — 识别中..."
            statusItem.button?.contentTintColor = .systemOrange
        }
        statusItem.button?.toolTip = tooltip
    }
}
