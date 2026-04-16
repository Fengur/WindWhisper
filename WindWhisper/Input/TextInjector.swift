import Cocoa

/// 将识别文本注入到当前焦点窗口。
/// 策略：备份粘贴板 → 写入文本 → 模拟 Cmd+V → 恢复粘贴板。
class TextInjector {

    func inject(text: String) {
        let pasteboard = NSPasteboard.general

        // 备份当前粘贴板
        let backup = pasteboard.string(forType: .string)

        // 写入识别文本
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 短暂延迟确保粘贴板就绪
        usleep(50_000) // 50ms

        // 模拟 Cmd+V
        simulatePaste()

        // 恢复粘贴板（延迟一点，等粘贴完成）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let backup {
                pasteboard.clearContents()
                pasteboard.setString(backup, forType: .string)
            }
        }

        print("[WindWhisper] Injected: \(text)")
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Key codes: V = 9, Cmd = flag
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
