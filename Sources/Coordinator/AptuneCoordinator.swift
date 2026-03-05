import CLI
import Foundation
import VAD
import VolumeControl

public final class AptuneCoordinator {
    private let config: AptuneConfig
    private let volumeDucker: VolumeDucking
    private let logger: Logger

    private var speaking = false
    private let stateQueue = DispatchQueue(label: "aptune.coordinator")

    public init(config: AptuneConfig, volumeDucker: VolumeDucking, logger: Logger) {
        self.config = config
        self.volumeDucker = volumeDucker
        self.logger = logger
    }

    public func handleSpeechState(_ state: SpeechState) {
        stateQueue.async {
            self.logger.debug("Speech state changed: speaking=\(state.isSpeaking) confidence=\(state.confidence)")
            if state.isSpeaking {
                guard !self.speaking else { return }
                self.speaking = true
                self.logger.info("Speech detected; ducking volume")
                self.volumeDucker.duck(to: self.config.downTo, attackMs: self.config.attackMs)
                return
            }

            guard self.speaking else { return }
            self.speaking = false
            self.logger.info("Speech ended; restoring volume")
            self.volumeDucker.restore(releaseMs: self.config.releaseMs)
        }
    }

    public func shutdown() {
        stateQueue.sync {
            volumeDucker.stopAndRestore()
            speaking = false
        }
    }
}
