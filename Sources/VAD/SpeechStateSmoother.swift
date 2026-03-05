import Foundation

public final class SpeechStateSmoother {
    private let onsetDebounceSec: TimeInterval
    private let holdSec: TimeInterval

    private var smoothedSpeaking = false
    private var speakingCandidateSince: TimeInterval?
    private var silentCandidateSince: TimeInterval?

    public init(onsetDebounceMs: Int = 60, holdMs: Int) {
        self.onsetDebounceSec = TimeInterval(onsetDebounceMs) / 1000
        self.holdSec = TimeInterval(holdMs) / 1000
    }

    public func process(rawSpeaking: Bool, confidence: Float, timestamp: TimeInterval) -> SpeechState? {
        if smoothedSpeaking {
            if rawSpeaking {
                silentCandidateSince = nil
                return nil
            }

            if silentCandidateSince == nil {
                silentCandidateSince = timestamp
                return nil
            }

            if let started = silentCandidateSince, timestamp - started >= holdSec {
                smoothedSpeaking = false
                silentCandidateSince = nil
                return SpeechState(isSpeaking: false, confidence: confidence, timestamp: timestamp)
            }
            return nil
        }

        if !rawSpeaking {
            speakingCandidateSince = nil
            return nil
        }

        if speakingCandidateSince == nil {
            speakingCandidateSince = timestamp
            return nil
        }

        if let started = speakingCandidateSince, timestamp - started >= onsetDebounceSec {
            smoothedSpeaking = true
            speakingCandidateSince = nil
            return SpeechState(isSpeaking: true, confidence: confidence, timestamp: timestamp)
        }

        return nil
    }

    public func reset() {
        smoothedSpeaking = false
        speakingCandidateSince = nil
        silentCandidateSince = nil
    }
}
