import Foundation

public struct BuiltInMicLaunchCommand: Equatable {
    public let showHelp: Bool
    public let listDevices: Bool
    public let onlyRoute: Bool
    public let replaceRunningInstance: Bool
    public let inputQuery: String?
    public let outputQuery: String?
    public let aptuneArguments: [String]

    public init(
        showHelp: Bool = false,
        listDevices: Bool = false,
        onlyRoute: Bool = false,
        replaceRunningInstance: Bool = false,
        inputQuery: String? = nil,
        outputQuery: String? = nil,
        aptuneArguments: [String] = []
    ) {
        self.showHelp = showHelp
        self.listDevices = listDevices
        self.onlyRoute = onlyRoute
        self.replaceRunningInstance = replaceRunningInstance
        self.inputQuery = inputQuery
        self.outputQuery = outputQuery
        self.aptuneArguments = aptuneArguments
    }
}

public struct InstallBuiltInMicPluginCommand: Equatable {
    public let showHelp: Bool
    public let appName: String

    public init(showHelp: Bool = false, appName: String = "Aptune Built-in Mic") {
        self.showHelp = showHelp
        self.appName = appName
    }
}

public enum CLICommand: Equatable {
    case run(AptuneConfig)
    case showVersion
    case showHelp
    case useBuiltInMic(BuiltInMicLaunchCommand)
    case installBuiltInMicPlugin(InstallBuiltInMicPluginCommand)
}
