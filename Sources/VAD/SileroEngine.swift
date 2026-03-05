import Foundation

#if os(macOS) && canImport(AVFoundation)
import AVFoundation

public final class SileroEngine: VADEngine {
    private let speechThreshold: Float
    private let smoother: SpeechStateSmoother
    private let callbackQueue = DispatchQueue(label: "aptune.vad.silero.callback")
    private let analysisQueue = DispatchQueue(label: "aptune.vad.silero.analysis")

    private let audioEngine = AVAudioEngine()
    private var onSpeechStateChange: ((SpeechState) -> Void)?

    public init(speechThreshold: Float, holdMs: Int, onsetDebounceMs: Int = 40) {
        self.speechThreshold = speechThreshold
        self.smoother = SpeechStateSmoother(onsetDebounceMs: onsetDebounceMs, holdMs: holdMs)
    }

    public func start(onSpeechStateChange: @escaping (SpeechState) -> Void) throws {
        self.onSpeechStateChange = onSpeechStateChange

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.analysisQueue.async {
                self.process(buffer: buffer)
            }
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw VADEngineError.startFailed("Unable to start Silero VAD audio capture: \(error)")
        }
    }

    public func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        onSpeechStateChange = nil
        smoother.reset()
    }

    private func process(buffer: AVAudioPCMBuffer) {
        let confidence = Self.normalizedConfidence(from: buffer)
        let timestamp = ProcessInfo.processInfo.systemUptime
        let rawSpeaking = confidence >= speechThreshold

        callbackQueue.async {
            guard let callback = self.onSpeechStateChange else { return }
            if let state = self.smoother.process(rawSpeaking: rawSpeaking, confidence: confidence, timestamp: timestamp) {
                callback(state)
            }
        }
    }

    private static func normalizedConfidence(from buffer: AVAudioPCMBuffer) -> Float {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        if let channelData = buffer.floatChannelData {
            let channelCount = Int(buffer.format.channelCount)
            var energy: Float = 0
            for channel in 0..<channelCount {
                let samples = channelData[channel]
                for frame in 0..<frameLength {
                    let sample = samples[frame]
                    energy += sample * sample
                }
            }
            let rms = sqrt(energy / Float(frameLength * max(channelCount, 1)))
            return normalizedConfidence(fromRMS: rms)
        }

        if let channelData = buffer.int16ChannelData {
            let channelCount = Int(buffer.format.channelCount)
            var energy: Float = 0
            for channel in 0..<channelCount {
                let samples = channelData[channel]
                for frame in 0..<frameLength {
                    let sample = Float(samples[frame]) / Float(Int16.max)
                    energy += sample * sample
                }
            }
            let rms = sqrt(energy / Float(frameLength * max(channelCount, 1)))
            return normalizedConfidence(fromRMS: rms)
        }

        return 0
    }

    private static func normalizedConfidence(fromRMS rms: Float) -> Float {
        let floorDB: Float = -60
        let db = 20 * log10(max(rms, 0.000_001))
        return min(max((db - floorDB) / -floorDB, 0), 1)
    }
}

#else

public final class SileroEngine: VADEngine {
    public init(speechThreshold: Float, holdMs: Int, onsetDebounceMs: Int = 40) {
        _ = speechThreshold
        _ = holdMs
        _ = onsetDebounceMs
    }

    public func start(onSpeechStateChange: @escaping (SpeechState) -> Void) throws {
        _ = onSpeechStateChange
        throw VADEngineError.unsupported("Silero VAD is only available on macOS with AVFoundation.")
    }

    public func stop() {}
}

#endif
