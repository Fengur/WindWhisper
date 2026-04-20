import Foundation

enum Log {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private static let logFileURL: URL? = {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs/WindWhisper", isDirectory: true)
        guard let dir else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileName = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()
        return dir.appendingPathComponent("\(fileName).log")
    }()

    static func info(_ message: String, file: String = #file, line: Int = #line) {
        write("INFO", message, file: file, line: line)
    }

    static func error(_ message: String, file: String = #file, line: Int = #line) {
        write("ERROR", message, file: file, line: line)
    }

    private static func write(_ level: String, _ message: String, file: String, line: Int) {
        let timestamp = dateFormatter.string(from: Date())
        let source = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        let entry = "[\(timestamp)] [\(level)] [\(source):\(line)] \(message)"

        print(entry)

        guard let url = logFileURL else { return }
        let data = (entry + "\n").data(using: .utf8) ?? Data()
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: url)
        }
    }

    static var logFilePath: String? {
        logFileURL?.path
    }
}
