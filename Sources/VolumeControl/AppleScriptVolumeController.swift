import Foundation

public final class AppleScriptVolumeController: SystemVolumeControlling {
    public init() {}

    public func getCurrentVolume() throws -> Double {
        let output = try runAppleScript("output volume of (get volume settings)")
        guard let value = Double(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw VolumeControllerError.invalidResponse("Unexpected volume value: \(output)")
        }
        return min(max(value / 100.0, 0), 1)
    }

    public func setVolume(_ fraction: Double) throws {
        let clamped = min(max(fraction, 0), 1)
        let percent = Int((clamped * 100).rounded())
        _ = try runAppleScript("set volume output volume \(percent)")
    }

    private func runAppleScript(_ script: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw VolumeControllerError.commandFailed("Unable to execute osascript: \(error)")
        }

        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw VolumeControllerError.commandFailed("osascript failed: \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        return stdout
    }
}
