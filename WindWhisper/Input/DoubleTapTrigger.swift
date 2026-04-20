import Cocoa

/// 双击 Control 键触发器。
class DoubleTapTrigger {
    static let shared = DoubleTapTrigger()

    private var eventTap: CFMachPort?
    private var callback: (() -> Void)?
    private var lastCtrlPressTime: CFAbsoluteTime = 0
    private var wasCtrlDown = false
    private var otherKeyPressed = false
    private let doubleTapInterval: TimeInterval = 0.35

    private init() {}

    func register(action: @escaping () -> Void) {
        self.callback = action

        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let trigger = Unmanaged<DoubleTapTrigger>.fromOpaque(refcon).takeUnretainedValue()
                trigger.handleEvent(event)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            Log.error("DoubleTapTrigger: Failed to create event tap. Grant Accessibility permission.")
            showAccessibilityAlert()
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        Log.info("DoubleTapTrigger: registered (double-tap Control)")
    }

    private func handleEvent(_ event: CGEvent) {
        let type = event.type

        if type == .keyDown {
            otherKeyPressed = true
            return
        }

        guard type == .flagsChanged else { return }

        let ctrlDown = event.flags.contains(.maskControl)
        let hasOtherModifiers = !event.flags.intersection([.maskCommand, .maskAlternate, .maskShift]).isEmpty

        if ctrlDown && !wasCtrlDown {
            Log.info("DoubleTapTrigger: ctrl DOWN, otherMods=\(hasOtherModifiers), flags=\(event.flags.rawValue)")
            otherKeyPressed = false
            if hasOtherModifiers {
                otherKeyPressed = true
            }
        }

        if !ctrlDown && wasCtrlDown {
            Log.info("DoubleTapTrigger: ctrl UP, otherKeyPressed=\(otherKeyPressed), otherMods=\(hasOtherModifiers)")
        }

        if !ctrlDown && wasCtrlDown && !otherKeyPressed && !hasOtherModifiers {
            let now = CFAbsoluteTimeGetCurrent()
            let elapsed = now - lastCtrlPressTime

            if elapsed < doubleTapInterval && lastCtrlPressTime > 0 {
                Log.info("DoubleTapTrigger: double-tap Control detected")
                lastCtrlPressTime = 0
                DispatchQueue.main.async { [weak self] in
                    self?.callback?()
                }
            } else {
                lastCtrlPressTime = now
            }
        }

        wasCtrlDown = ctrlDown
    }

    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "WindWhisper 需要「辅助功能」权限才能使用双击 Control 触发录音。\n\n请前往：系统设置 → 隐私与安全性 → 辅助功能，找到 WindWhisper 并开启。\n\n开启后需要重新启动 WindWhisper。\n\n未开启时仍可通过点击悬浮按钮或状态栏图标使用。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后再说")

            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
