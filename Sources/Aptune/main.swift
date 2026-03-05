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

    init(coordinator: AptuneCoordinator, engine: VADEngine, logger: Logger) {
        self.coordinator = coordinator
        self.engine = engine
        self.logger = logger
    }

    func run() throws {
        try engine.start { [weak self] state in
            self?.coordinator.handleSpeechState(state)
        }
        logger.info("Aptune started. Press Ctrl+C to stop.")
        RunLoop.main.run()
    }

    func shutdownAndExit(code: Int32) -> Never {
        logger.info("Shutting down Aptune")
        engine.stop()
        coordinator.shutdown()
        Darwin.exit(code)
    }
}

func buildEngine(config: AptuneConfig) -> VADEngine {
    switch config.engine {
    case .native:
        return NativeSoundAnalysisEngine(speechThreshold: Float(config.speechThreshold), holdMs: config.holdMs)
    case .silero:
        return SileroEngine()
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
        let config = try CLIParser.parse(arguments: Array(CommandLine.arguments.dropFirst()))
        let logger = Logger(level: config.logLevel)

        try MicrophonePermissionChecker.ensureMicrophoneAccess()

        let volumeController = AppleScriptVolumeController()
        let volumeDucker = VolumeDucker(controller: volumeController)
        let coordinator = AptuneCoordinator(config: config, volumeDucker: volumeDucker, logger: logger)
        let engine = buildEngine(config: config)
        let runtime = AppRuntime(coordinator: coordinator, engine: engine, logger: logger)

        installSignalHandlers(runtime)
        try runtime.run()
        return 0
    } catch {
        fputs("aptune: \(error)\n", stderr)
        return 1
    }
}

Darwin.exit(main())
