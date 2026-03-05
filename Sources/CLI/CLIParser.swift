import Foundation

public enum CLIError: Error, CustomStringConvertible, Equatable {
    case missingValue(flag: String)
    case unknownFlag(String)
    case invalidValue(flag: String, message: String)

    public var description: String {
        switch self {
        case .missingValue(let flag):
            return "Missing value for \(flag)"
        case .unknownFlag(let flag):
            return "Unknown flag: \(flag)"
        case .invalidValue(let flag, let message):
            return "Invalid value for \(flag): \(message)"
        }
    }
}

public enum CLIParser {
    public static func parse(arguments: [String]) throws -> AptuneConfig {
        var downTo = 0.25
        var engine = EngineChoice.native
        var attackMs = 80
        var releaseMs = 600
        var holdMs = 250
        var logLevel = LogLevel.info
        var speechThreshold = 0.55

        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "--downTo":
                downTo = try parseDoubleValue(arguments: arguments, index: &index, flag: arg)
            case "--engine":
                let value = try parseStringValue(arguments: arguments, index: &index, flag: arg)
                guard let parsed = EngineChoice(rawValue: value) else {
                    throw CLIError.invalidValue(flag: arg, message: "expected one of: \(EngineChoice.allCases.map(\.rawValue).joined(separator: ", "))")
                }
                engine = parsed
            case "--attack-ms":
                attackMs = try parseIntValue(arguments: arguments, index: &index, flag: arg)
            case "--release-ms":
                releaseMs = try parseIntValue(arguments: arguments, index: &index, flag: arg)
            case "--hold-ms":
                holdMs = try parseIntValue(arguments: arguments, index: &index, flag: arg)
            case "--log-level":
                let value = try parseStringValue(arguments: arguments, index: &index, flag: arg)
                guard let parsed = LogLevel(rawValue: value) else {
                    throw CLIError.invalidValue(flag: arg, message: "expected one of: \(LogLevel.allCases.map(\.rawValue).joined(separator: ", "))")
                }
                logLevel = parsed
            case "--speech-threshold":
                speechThreshold = try parseDoubleValue(arguments: arguments, index: &index, flag: arg)
            default:
                throw CLIError.unknownFlag(arg)
            }
            index += 1
        }

        return try AptuneConfig(
            downTo: downTo,
            engine: engine,
            attackMs: attackMs,
            releaseMs: releaseMs,
            holdMs: holdMs,
            logLevel: logLevel,
            speechThreshold: speechThreshold
        )
    }

    private static func parseStringValue(arguments: [String], index: inout Int, flag: String) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw CLIError.missingValue(flag: flag)
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func parseIntValue(arguments: [String], index: inout Int, flag: String) throws -> Int {
        let value = try parseStringValue(arguments: arguments, index: &index, flag: flag)
        guard let parsed = Int(value) else {
            throw CLIError.invalidValue(flag: flag, message: "expected integer")
        }
        return parsed
    }

    private static func parseDoubleValue(arguments: [String], index: inout Int, flag: String) throws -> Double {
        let value = try parseStringValue(arguments: arguments, index: &index, flag: flag)
        guard let parsed = Double(value) else {
            throw CLIError.invalidValue(flag: flag, message: "expected number")
        }
        return parsed
    }
}
