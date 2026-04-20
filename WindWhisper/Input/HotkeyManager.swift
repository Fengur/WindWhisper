import Cocoa
import Carbon

/// 全局快捷键管理，支持动态配置。
class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventTap: CFMachPort?
    private var callback: (() -> Void)?
    private var targetKeyCode: CGKeyCode
    private var targetModifiers: CGEventFlags

    private static let relevantModifiersMask: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]

    private init() {
        let config = HotkeyConfig.load()
        targetKeyCode = config.keyCode
        targetModifiers = config.modifiers
    }

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

        let config = HotkeyConfig.load()
        print("[HotkeyManager] Registered \(config.displayString)")
    }

    func updateHotkey(_ config: HotkeyConfig) {
        targetKeyCode = config.keyCode
        targetModifiers = config.modifiers
        print("[HotkeyManager] Updated hotkey to \(config.displayString)")
    }

    private func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let pressedModifiers = event.flags.intersection(Self.relevantModifiersMask)

        if keyCode == targetKeyCode && pressedModifiers == targetModifiers {
            DispatchQueue.main.async { [weak self] in
                self?.callback?()
            }
            return nil
        }

        return Unmanaged.passRetained(event)
    }
}
