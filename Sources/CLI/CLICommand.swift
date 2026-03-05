import Foundation

public enum CLICommand: Equatable {
    case run(AptuneConfig)
    case showVersion
    case showHelp
}
