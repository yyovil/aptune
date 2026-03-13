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
    public static let usage = """
    Usage: aptune [options]

    Aptune is a cli tool for MacOS that ducks system volume while you speak.

    Options:
      --down-to <0...1>          Target volume multiplier while speaking (default: 0.25)
      --attack-ms <int>          Duck ramp duration in milliseconds (default: 80)
      --release-ms <int>         Restore ramp duration in milliseconds (default: 600)
      --hold-ms <int>            Silence hold before restore in milliseconds (default: 250)
      --log-level info|debug     Log verbosity (default: info)
      --speech-threshold <0...1> Speech confidence threshold (default: 0.7)
      -h, --help, help           Show this help
      -v, --version, version     Show CLI version
    """

    public static func parse(arguments: [String]) throws -> CLICommand {
        if arguments.contains("--help") || arguments.contains("-h") || arguments.contains("help") {
            return .showHelp
        }

        if arguments.contains("--version") || arguments.contains("-v") || arguments.contains("version") {
            return .showVersion
        }

        var downTo = 0.25
        var attackMs = 80
        var releaseMs = 600
        var holdMs = 250
        var logLevel = LogLevel.info
        var speechThreshold = 0.7

        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "--down-to":
                downTo = try parseDoubleValue(arguments: arguments, index: &index, flag: arg)
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

        return .run(try AptuneConfig(
            downTo: downTo,
            attackMs: attackMs,
            releaseMs: releaseMs,
            holdMs: holdMs,
            logLevel: logLevel,
            speechThreshold: speechThreshold
        ))
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
