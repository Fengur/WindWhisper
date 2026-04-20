import Carbon
import Cocoa

struct HotkeyConfig {
    var keyCode: CGKeyCode
    var modifiers: CGEventFlags

    static let `default` = HotkeyConfig(keyCode: 15, modifiers: [.maskCommand, .maskAlternate])

    func save() {
        UserDefaults.standard.set(Int(keyCode), forKey: "hotkey.keyCode")
        UserDefaults.standard.set(modifiers.rawValue, forKey: "hotkey.modifiers")
    }

    static func load() -> HotkeyConfig {
        guard UserDefaults.standard.object(forKey: "hotkey.keyCode") != nil else {
            return .default
        }
        let keyCode = CGKeyCode(UserDefaults.standard.integer(forKey: "hotkey.keyCode"))
        let rawModifiers = UserDefaults.standard.object(forKey: "hotkey.modifiers") as? UInt64 ?? Self.default.modifiers.rawValue
        return HotkeyConfig(keyCode: keyCode, modifiers: CGEventFlags(rawValue: rawModifiers))
    }

    static func fromNSEventFlags(_ flags: NSEvent.ModifierFlags) -> CGEventFlags {
        var result: CGEventFlags = []
        if flags.contains(.command)  { result.insert(.maskCommand) }
        if flags.contains(.option)   { result.insert(.maskAlternate) }
        if flags.contains(.control)  { result.insert(.maskControl) }
        if flags.contains(.shift)    { result.insert(.maskShift) }
        return result
    }

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.maskControl)   { parts.append("Ctrl") }
        if modifiers.contains(.maskAlternate) { parts.append("Opt") }
        if modifiers.contains(.maskShift)     { parts.append("Shift") }
        if modifiers.contains(.maskCommand)   { parts.append("Cmd") }
        parts.append(Self.keyCodeToString(keyCode))
        return parts.joined(separator: "+")
    }

    private static func keyCodeToString(_ keyCode: CGKeyCode) -> String {
        let map: [CGKeyCode: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".",
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            103: "F11", 105: "F13", 107: "F14", 109: "F10", 111: "F12",
            113: "F15", 118: "F4", 119: "F2", 120: "F1",
            122: "F1", 123: "Left", 124: "Right", 125: "Down", 126: "Up",
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }
}
