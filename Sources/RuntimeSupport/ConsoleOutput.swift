import Darwin
import Foundation

public enum ConsoleOutput {
    public static func writeStdoutLine(_ message: String) {
        writeLine(message, descriptor: STDOUT_FILENO, stream: stdout)
    }

    public static func writeStderrLine(_ message: String) {
        writeLine(message, descriptor: STDERR_FILENO, stream: stderr)
    }

    public static func shouldWriteToStdout() -> Bool {
        shouldWrite(to: STDOUT_FILENO)
    }

    public static func shouldWriteToStderr() -> Bool {
        shouldWrite(to: STDERR_FILENO)
    }

    private static func writeLine(_ message: String, descriptor: Int32, stream: UnsafeMutablePointer<FILE>) {
        guard shouldWrite(to: descriptor) else { return }
        fputs("\(message)\n", stream)
        fflush(stream)
    }

    private static func shouldWrite(to descriptor: Int32) -> Bool {
        guard isatty(descriptor) == 1 else {
            return true
        }

        let foregroundProcessGroup = tcgetpgrp(descriptor)
        if foregroundProcessGroup == -1 {
            return true
        }

        return foregroundProcessGroup == getpgrp()
    }
}
