import Cocoa
import Carbon

/// 全局快捷键管理。默认 Cmd+Opt+R。
class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventTap: CFMachPort?
    private var callback: (() -> Void)?

    // Cmd + Option + R
    private let targetKeyCode: CGKeyCode = 15 // R
    private let targetModifiers: CGEventFlags = [.maskCommand, .maskAlternate]

    private init() {}

    func register(action: @escaping () -> Void) {
        self.callback = action

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            print("[HotkeyManager] Failed to create event tap. Grant Accessibility permission.")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        print("[HotkeyManager] Registered Cmd+Opt+R")
    }

    private func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        if keyCode == targetKeyCode
            && flags.contains(.maskCommand)
            && flags.contains(.maskAlternate)
        {
            DispatchQueue.main.async { [weak self] in
                self?.callback?()
            }
            return nil // 吞掉这个按键
        }

        return Unmanaged.passRetained(event)
    }
}
