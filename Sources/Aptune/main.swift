import AudioCapture
import CLI
import Coordinator
import Dispatch
import Foundation
import VAD
import VolumeControl
import Darwin

private var signalSources: [DispatchSourceSignal] = []

final class AppRuntime {
    private let coordinator: AptuneCoordinator
    private let engine: VADEngine
    private let logger: Logger
    private let startupMessage: String

    init(coordinator: AptuneCoordinator, engine: VADEngine, logger: Logger, startupMessage: String) {
        self.coordinator = coordinator
        self.engine = engine
        self.logger = logger
        self.startupMessage = startupMessage
    }

    func run() throws {
        try engine.start { [weak self] state in
            self?.coordinator.handleSpeechState(state)
        }
        logger.info(startupMessage)
        RunLoop.main.run()
    }

    func shutdownAndExit(code: Int32) -> Never {
        logger.info("Shutting down Aptune")
        engine.stop()
        coordinator.shutdown()
        Darwin.exit(code)
    }
}

func installSignalHandlers(_ runtime: AppRuntime) {
    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)

    let queue = DispatchQueue(label: "aptune.signal")
    signalSources = [SIGINT, SIGTERM].compactMap { sig -> DispatchSourceSignal? in
        let source = DispatchSource.makeSignalSource(signal: sig, queue: queue)
        source.setEventHandler {
            runtime.shutdownAndExit(code: 0)
        }
        source.resume()
        return source
    }

}

func main() -> Int32 {
    do {
        let command = try CLIParser.parse(arguments: Array(CommandLine.arguments.dropFirst()))

        switch command {
        case .showHelp:
            print(CLIParser.usage)
            return 0
        case .showVersion:
            print(AptuneVersion.summary)
            return 0
        case .run(let config):
            let logger = Logger(level: config.logLevel)

            try MicrophonePermissionChecker.ensureMicrophoneAccess()

            let volumeController = AppleScriptVolumeController()
            let volumeDucker = VolumeDucker(controller: volumeController)
            let coordinator = AptuneCoordinator(config: config, volumeDucker: volumeDucker, logger: logger)
            let engine = FireRedEngine(speechThreshold: Float(config.speechThreshold), holdMs: config.holdMs)
            let startupMessage = "Aptune \(AptuneVersion.current) started with FireRed backend (\(AptuneVersion.profile)). Press Ctrl+C to stop."
            let runtime = AppRuntime(coordinator: coordinator, engine: engine, logger: logger, startupMessage: startupMessage)

            installSignalHandlers(runtime)
            try runtime.run()
            return 0
        }
    } catch {
        fputs("aptune: \(error)\n", stderr)
        return 1
    }
}

Darwin.exit(main())
