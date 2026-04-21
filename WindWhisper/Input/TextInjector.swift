import Cocoa

class TextInjector {

    static func ensureAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        Log.info("TextInjector: accessibility trusted = \(trusted)")
    }

    func inject(text: String) {
        let pasteboard = NSPasteboard.general
        let backup = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        usleep(50_000)

        if AXIsProcessTrusted() {
            simulatePaste()
            Log.info("Injected (pasted): \(text)")
        } else {
            Log.info("Injected (clipboard only, no accessibility): \(text)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let backup {
                pasteboard.clearContents()
                pasteboard.setString(backup, forType: .string)
            }
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            Log.error("TextInjector: failed to create CGEvent")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
