import Foundation
import RuntimeSupport

public final class Logger {
    private let level: LogLevel
    private let queue = DispatchQueue(label: "aptune.logger")

    public init(level: LogLevel) {
        self.level = level
    }

    public func info(_ message: String) {
        log(prefix: "INFO", message: message)
    }

    public func debug(_ message: String) {
        guard level == .debug else { return }
        log(prefix: "DEBUG", message: message)
    }

    private func log(prefix: String, message: String) {
        queue.async {
            ConsoleOutput.writeStdoutLine("[\(prefix)] \(message)")
        }
    }
}
