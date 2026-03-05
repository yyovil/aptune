import Foundation

public enum EngineChoice: String, CaseIterable {
    case native
    case silero
}

public enum LogLevel: String, CaseIterable {
    case info
    case debug
}

public struct AptuneConfig: Equatable {
    public let downTo: Double
    public let engine: EngineChoice
    public let attackMs: Int
    public let releaseMs: Int
    public let holdMs: Int
    public let logLevel: LogLevel
    public let speechThreshold: Double

    public init(
        downTo: Double = 0.25,
        engine: EngineChoice = .native,
        attackMs: Int = 80,
        releaseMs: Int = 600,
        holdMs: Int = 250,
        logLevel: LogLevel = .info,
        speechThreshold: Double = 0.55
    ) throws {
        guard (0...1).contains(downTo) else {
            throw CLIError.invalidValue(flag: "--downTo", message: "must be between 0 and 1")
        }
        guard (0...1).contains(speechThreshold) else {
            throw CLIError.invalidValue(flag: "--speech-threshold", message: "must be between 0 and 1")
        }
        guard attackMs >= 0 else {
            throw CLIError.invalidValue(flag: "--attack-ms", message: "must be >= 0")
        }
        guard releaseMs >= 0 else {
            throw CLIError.invalidValue(flag: "--release-ms", message: "must be >= 0")
        }
        guard holdMs >= 0 else {
            throw CLIError.invalidValue(flag: "--hold-ms", message: "must be >= 0")
        }

        self.downTo = downTo
        self.engine = engine
        self.attackMs = attackMs
        self.releaseMs = releaseMs
        self.holdMs = holdMs
        self.logLevel = logLevel
        self.speechThreshold = speechThreshold
    }
}
