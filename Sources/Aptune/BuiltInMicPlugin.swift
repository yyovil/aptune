import CLI
import CoreAudio
import Darwin
import Foundation

enum BuiltInMicPluginError: Error, CustomStringConvertible {
    case unsupported(String)
    case coreAudio(String, OSStatus)
    case aptuneNotFound
    case deviceNotFound(query: String, kind: String, available: [String])
    case ambiguousDevice(query: String, kind: String, matches: [String])
    case processFailed(String)

    var description: String {
        switch self {
        case .unsupported(let message):
            return message
        case .coreAudio(let operation, let status):
            return "\(operation) failed with OSStatus \(status)."
        case .aptuneNotFound:
            return "Could not find the aptune executable for relaunch in the current invocation or PATH."
        case .deviceNotFound(let query, let kind, let available):
            let choices = available.isEmpty ? "No \(kind) devices were found." : "Available \(kind) devices: \(available.joined(separator: ", "))."
            return "Could not find a \(kind) device matching '\(query)'. \(choices)"
        case .ambiguousDevice(let query, let kind, let matches):
            return "Found multiple \(kind) devices matching '\(query)': \(matches.joined(separator: ", "))."
        case .processFailed(let message):
            return message
        }
    }
}

private struct AudioDeviceDescriptor {
    let id: AudioDeviceID
    let name: String
    let uid: String?
    let inputChannels: Int
    let outputChannels: Int
    let transportType: UInt32?

    var isInputCapable: Bool { inputChannels > 0 }
    var isOutputCapable: Bool { outputChannels > 0 }
}

private struct AudioCatalog {
    let devices: [AudioDeviceDescriptor]
    let defaultInputID: AudioDeviceID?
    let defaultOutputID: AudioDeviceID?

    var inputDevices: [AudioDeviceDescriptor] {
        devices
            .filter(\.isInputCapable)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var outputDevices: [AudioDeviceDescriptor] {
        devices
            .filter(\.isOutputCapable)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private func propertyAddress(
    selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
}

private func allAudioDeviceIDs() throws -> [AudioDeviceID] {
    var address = propertyAddress(selector: kAudioHardwarePropertyDevices)
    var dataSize: UInt32 = 0
    let sizeStatus = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
    guard sizeStatus == noErr else {
        throw BuiltInMicPluginError.coreAudio("Loading audio device list size", sizeStatus)
    }

    let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
    let dataStatus = deviceIDs.withUnsafeMutableBytes { bytes -> OSStatus in
        guard let baseAddress = bytes.baseAddress else {
            return kAudioHardwareUnspecifiedError
        }

        return AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            baseAddress
        )
    }
    guard dataStatus == noErr else {
        throw BuiltInMicPluginError.coreAudio("Loading audio device list", dataStatus)
    }

    return deviceIDs
}

private func stringProperty(
    selector: AudioObjectPropertySelector,
    objectID: AudioObjectID,
    label: String
) throws -> String {
    var address = propertyAddress(selector: selector)
    var dataSize = UInt32(MemoryLayout<CFString?>.size)
    var value: CFString?
    let status = withUnsafeMutablePointer(to: &value) { pointer in
        AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, pointer)
    }
    guard status == noErr else {
        throw BuiltInMicPluginError.coreAudio("Loading \(label)", status)
    }
    return (value ?? "" as CFString) as String
}

private func channelCount(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) throws -> Int {
    var address = propertyAddress(selector: kAudioDevicePropertyStreamConfiguration, scope: scope)
    var dataSize: UInt32 = 0
    let sizeStatus = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
    guard sizeStatus == noErr else {
        throw BuiltInMicPluginError.coreAudio("Loading stream configuration size", sizeStatus)
    }

    let rawPointer = UnsafeMutableRawPointer.allocate(
        byteCount: Int(dataSize),
        alignment: MemoryLayout<AudioBufferList>.alignment
    )
    defer { rawPointer.deallocate() }

    let bufferListPointer = rawPointer.assumingMemoryBound(to: AudioBufferList.self)
    let dataStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferListPointer)
    guard dataStatus == noErr else {
        throw BuiltInMicPluginError.coreAudio("Loading stream configuration", dataStatus)
    }

    let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
    return bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
}

private func transportType(deviceID: AudioDeviceID) throws -> UInt32 {
    var address = propertyAddress(selector: kAudioDevicePropertyTransportType)
    var value: UInt32 = 0
    var dataSize = UInt32(MemoryLayout<UInt32>.size)
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value)
    guard status == noErr else {
        throw BuiltInMicPluginError.coreAudio("Loading device transport type", status)
    }
    return value
}

private func loadDeviceDescriptor(id: AudioDeviceID) throws -> AudioDeviceDescriptor {
    AudioDeviceDescriptor(
        id: id,
        name: try stringProperty(selector: kAudioObjectPropertyName, objectID: id, label: "device name"),
        uid: try? stringProperty(selector: kAudioDevicePropertyDeviceUID, objectID: id, label: "device UID"),
        inputChannels: try channelCount(deviceID: id, scope: kAudioDevicePropertyScopeInput),
        outputChannels: try channelCount(deviceID: id, scope: kAudioDevicePropertyScopeOutput),
        transportType: try? transportType(deviceID: id)
    )
}

private func getDefaultDeviceID(selector: AudioObjectPropertySelector) throws -> AudioDeviceID? {
    var address = propertyAddress(selector: selector)
    guard AudioObjectHasProperty(AudioObjectID(kAudioObjectSystemObject), &address) else {
        return nil
    }

    var value = AudioDeviceID(0)
    var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &value)
    guard status == noErr else {
        throw BuiltInMicPluginError.coreAudio("Loading default device", status)
    }

    return value == 0 ? nil : value
}

private func setDefaultDevice(selector: AudioObjectPropertySelector, deviceID: AudioDeviceID, label: String) throws {
    var address = propertyAddress(selector: selector)
    var mutableDeviceID = deviceID
    let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectSetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        dataSize,
        &mutableDeviceID
    )
    guard status == noErr else {
        throw BuiltInMicPluginError.coreAudio("Setting \(label)", status)
    }
}

private func loadAudioCatalog() throws -> AudioCatalog {
    let deviceIDs = try allAudioDeviceIDs()
    let devices = try deviceIDs.map(loadDeviceDescriptor)
    return AudioCatalog(
        devices: devices,
        defaultInputID: try getDefaultDeviceID(selector: kAudioHardwarePropertyDefaultInputDevice),
        defaultOutputID: try getDefaultDeviceID(selector: kAudioHardwarePropertyDefaultOutputDevice)
    )
}

private func resolveBuiltInInputDevice(in catalog: AudioCatalog) throws -> AudioDeviceDescriptor {
    let candidates = catalog.inputDevices.filter { device in
        device.transportType == kAudioDeviceTransportTypeBuiltIn ||
        device.name.localizedCaseInsensitiveContains("built-in") ||
        device.name.localizedCaseInsensitiveContains("macbook")
    }

    if let exactDefault = candidates.first(where: { $0.id == catalog.defaultInputID }) {
        return exactDefault
    }

    if let microphone = candidates.first(where: { $0.name.localizedCaseInsensitiveContains("microphone") }) {
        return microphone
    }

    if let first = candidates.first {
        return first
    }

    throw BuiltInMicPluginError.unsupported("Could not find a built-in microphone on this Mac.")
}

private func resolveDevice(query: String, kind: String, devices: [AudioDeviceDescriptor]) throws -> AudioDeviceDescriptor {
    let normalizedQuery = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

    func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    let exactMatches = devices.filter { normalized($0.name) == normalizedQuery || normalized($0.uid ?? "") == normalizedQuery }
    if exactMatches.count == 1 {
        return exactMatches[0]
    }
    if exactMatches.count > 1 {
        throw BuiltInMicPluginError.ambiguousDevice(query: query, kind: kind, matches: exactMatches.map(\.name))
    }

    let fuzzyMatches = devices.filter {
        normalized($0.name).contains(normalizedQuery) || normalized($0.uid ?? "").contains(normalizedQuery)
    }

    if fuzzyMatches.isEmpty {
        throw BuiltInMicPluginError.deviceNotFound(query: query, kind: kind, available: devices.map(\.name))
    }
    if fuzzyMatches.count > 1 {
        throw BuiltInMicPluginError.ambiguousDevice(query: query, kind: kind, matches: fuzzyMatches.map(\.name))
    }

    return fuzzyMatches[0]
}

private func transportDescription(_ transportType: UInt32?) -> String {
    guard let transportType else { return "unknown" }

    switch transportType {
    case kAudioDeviceTransportTypeBuiltIn:
        return "built-in"
    case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
        return "bluetooth"
    case kAudioDeviceTransportTypeUSB:
        return "usb"
    case kAudioDeviceTransportTypeAggregate:
        return "aggregate"
    case kAudioDeviceTransportTypeVirtual:
        return "virtual"
    case kAudioDeviceTransportTypeHDMI:
        return "hdmi"
    case kAudioDeviceTransportTypeDisplayPort:
        return "displayport"
    case kAudioDeviceTransportTypeAirPlay:
        return "airplay"
    default:
        return "transport-\(transportType)"
    }
}

func printBuiltInMicDeviceList() throws {
    let catalog = try loadAudioCatalog()

    print("Input devices:")
    for device in catalog.inputDevices {
        let marker = device.id == catalog.defaultInputID ? "*" : " "
        print("\(marker) \(device.name) [\(transportDescription(device.transportType))]")
    }

    print("")
    print("Output devices:")
    for device in catalog.outputDevices {
        let marker = device.id == catalog.defaultOutputID ? "*" : " "
        print("\(marker) \(device.name) [\(transportDescription(device.transportType))]")
    }
}

private func absoluteExecutableURL(path: String, currentDirectoryPath: String) -> URL? {
    let expandedPath = (path as NSString).expandingTildeInPath
    let candidatePath: String
    if expandedPath.hasPrefix("/") {
        candidatePath = expandedPath
    } else {
        candidatePath = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(expandedPath)
            .path
    }

    guard FileManager.default.isExecutableFile(atPath: candidatePath) else {
        return nil
    }

    return URL(fileURLWithPath: candidatePath).standardizedFileURL
}

private func currentAptuneExecutableURL(
    invocationPath: String = CommandLine.arguments[0],
    environment: [String: String] = ProcessInfo.processInfo.environment,
    currentDirectoryPath: String = FileManager.default.currentDirectoryPath
) throws -> URL {
    if invocationPath.contains("/") {
        if let executableURL = absoluteExecutableURL(path: invocationPath, currentDirectoryPath: currentDirectoryPath) {
            return executableURL
        }
    } else if let searchPath = environment["PATH"] {
        for component in searchPath.split(separator: ":", omittingEmptySubsequences: false) {
            let directory = component.isEmpty ? currentDirectoryPath : String(component)
            let candidatePath = URL(fileURLWithPath: directory, isDirectory: true)
                .appendingPathComponent(invocationPath)
                .path

            if FileManager.default.isExecutableFile(atPath: candidatePath) {
                return URL(fileURLWithPath: candidatePath).standardizedFileURL
            }
        }
    }

    throw BuiltInMicPluginError.aptuneNotFound
}

private func runAptune(at url: URL, arguments: [String]) throws -> Never {
    let process = Process()
    process.executableURL = url
    process.arguments = arguments
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    do {
        try process.run()
    } catch {
        throw BuiltInMicPluginError.processFailed("Unable to start aptune at '\(url.path)': \(error)")
    }

    process.waitUntilExit()
    exit(process.terminationStatus)
}

private func runningAptuneProcessIDs(excluding processID: Int32 = ProcessInfo.processInfo.processIdentifier) throws -> [Int32] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    process.arguments = ["-x", "aptune"]

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    do {
        try process.run()
    } catch {
        throw BuiltInMicPluginError.processFailed("Unable to launch pgrep: \(error)")
    }

    process.waitUntilExit()

    if process.terminationStatus == 1 {
        return []
    }

    guard process.terminationStatus == 0 else {
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
        throw BuiltInMicPluginError.processFailed("pgrep failed: \(stderrText)")
    }

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stdoutText = String(data: stdoutData, encoding: .utf8) ?? ""
    return stdoutText
        .split(whereSeparator: \.isNewline)
        .compactMap { Int32($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        .filter { $0 != processID }
}

private func processExists(_ processID: Int32) -> Bool {
    if Darwin.kill(processID, 0) == 0 {
        return true
    }

    return errno != ESRCH
}

private func terminateProcesses(_ processIDs: [Int32], timeout: TimeInterval = 5) throws {
    guard !processIDs.isEmpty else {
        return
    }

    for processID in processIDs {
        if Darwin.kill(processID, SIGTERM) != 0 && errno != ESRCH {
            throw BuiltInMicPluginError.processFailed("Unable to stop Aptune process \(processID): \(String(cString: strerror(errno)))")
        }
    }

    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        let remaining = processIDs.filter(processExists)
        if remaining.isEmpty {
            return
        }

        Thread.sleep(forTimeInterval: 0.1)
    }

    let remaining = processIDs.filter(processExists)
    guard remaining.isEmpty else {
        throw BuiltInMicPluginError.processFailed("Timed out waiting for Aptune to stop: \(remaining.map(String.init).joined(separator: ", "))")
    }
}

private func promptToReplaceExistingLauncher(appName: String) throws -> Bool {
    let escapedAppName = appName
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    let script = """
    display dialog "\(escapedAppName).app already exists in Applications. Replace it?" buttons {"Cancel", "Replace"} default button "Replace" cancel button "Cancel" with icon caution
    return "replace"
    """

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]

    let stderrPipe = Pipe()
    process.standardError = stderrPipe

    do {
        try process.run()
    } catch {
        throw BuiltInMicPluginError.processFailed("Unable to launch osascript: \(error)")
    }

    process.waitUntilExit()
    if process.terminationStatus == 0 {
        return true
    }

    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrText = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
    if stderrText.contains("User canceled") || stderrText.contains("(-128)") {
        return false
    }

    throw BuiltInMicPluginError.processFailed("Replacement prompt failed: \(stderrText)")
}

func runBuiltInMicCommand(_ command: BuiltInMicLaunchCommand) throws -> Never {
    let catalog = try loadAudioCatalog()

    let inputDevice: AudioDeviceDescriptor
    if let inputQuery = command.inputQuery {
        inputDevice = try resolveDevice(query: inputQuery, kind: "input", devices: catalog.inputDevices)
    } else {
        inputDevice = try resolveBuiltInInputDevice(in: catalog)
    }

    try setDefaultDevice(
        selector: kAudioHardwarePropertyDefaultInputDevice,
        deviceID: inputDevice.id,
        label: "default input device"
    )
    print("Input routed to: \(inputDevice.name)")

    if let outputQuery = command.outputQuery {
        let outputDevice = try resolveDevice(query: outputQuery, kind: "output", devices: catalog.outputDevices)
        try setDefaultDevice(
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            deviceID: outputDevice.id,
            label: "default output device"
        )
        try setDefaultDevice(
            selector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            deviceID: outputDevice.id,
            label: "default system output device"
        )
        print("Output routed to: \(outputDevice.name)")
    } else if let currentOutput = catalog.outputDevices.first(where: { $0.id == catalog.defaultOutputID }) {
        print("Output left unchanged: \(currentOutput.name)")
    }

    if command.replaceRunningInstance && !command.onlyRoute {
        let runningPIDs = try runningAptuneProcessIDs()
        if !runningPIDs.isEmpty {
            print("Restarting Aptune to pick up the new input route.")
            try terminateProcesses(runningPIDs)
        }
    }

    if command.onlyRoute {
        exit(0)
    }

    let aptuneURL = try currentAptuneExecutableURL()
    print("Launching aptune from: \(aptuneURL.path)")
    try runAptune(at: aptuneURL, arguments: command.aptuneArguments)
}

func installBuiltInMicPlugin(appName: String) throws {
    let aptuneURL = try currentAptuneExecutableURL()
    let fileManager = FileManager.default
    let destinationDirectory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications", isDirectory: true)
    let logDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Logs/Aptune", isDirectory: true)
    let logURL = logDirectory.appendingPathComponent("spotlight-launcher.log")
    let appURL = destinationDirectory.appendingPathComponent("\(appName).app", isDirectory: true)
    let temporaryAppURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("aptune-built-in-mic-\(UUID().uuidString).app", isDirectory: true)
    let escapedAptunePath = aptuneURL.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let escapedLogPath = logURL.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let escapedAppName = appName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")

    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)

    let applet = """
    on run
        set aptunePath to "\(escapedAptunePath)"
        set logPath to "\(escapedLogPath)"
        set shellCommand to "/usr/bin/nohup " & quoted form of aptunePath & " use-built-in-mic --replace-running >> " & quoted form of logPath & " 2>&1 &"

        try
            do shell script shellCommand
            display notification "Routing Aptune to the built-in microphone." with title "\(escapedAppName)"
        on error errMsg
            display dialog errMsg buttons {"OK"} default button "OK" with title "\(escapedAppName)"
        end try
    end run
    """

    let temporaryScriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("aptune-built-in-mic-\(UUID().uuidString).applescript")
    try applet.write(to: temporaryScriptURL, atomically: true, encoding: .utf8)
    defer {
        try? fileManager.removeItem(at: temporaryScriptURL)
        if fileManager.fileExists(atPath: temporaryAppURL.path) {
            try? fileManager.removeItem(at: temporaryAppURL)
        }
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osacompile")
    process.arguments = ["-o", temporaryAppURL.path, temporaryScriptURL.path]

    let stderrPipe = Pipe()
    process.standardError = stderrPipe

    do {
        try process.run()
    } catch {
        throw BuiltInMicPluginError.processFailed("Unable to launch osacompile: \(error)")
    }

    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
        throw BuiltInMicPluginError.processFailed("osacompile failed: \(stderrText)")
    }

    if fileManager.fileExists(atPath: appURL.path) {
        guard try promptToReplaceExistingLauncher(appName: appName) else {
            print("Left existing Spotlight launcher unchanged:")
            print(appURL.path)
            return
        }

        try fileManager.removeItem(at: appURL)
    }

    try fileManager.moveItem(at: temporaryAppURL, to: appURL)

    let mdimport = Process()
    mdimport.executableURL = URL(fileURLWithPath: "/usr/bin/mdimport")
    mdimport.arguments = [appURL.path]
    try? mdimport.run()
    mdimport.waitUntilExit()

    print("Installed Spotlight launcher:")
    print(appURL.path)
    print("")
    print("Open Spotlight and search for '\(appName)'.")
    print("Launcher log:")
    print(logURL.path)
}
