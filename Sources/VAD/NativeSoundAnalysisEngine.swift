import Foundation

#if os(macOS) && canImport(AVFoundation) && canImport(SoundAnalysis)
import AVFoundation
import SoundAnalysis

public final class NativeSoundAnalysisEngine: NSObject, VADEngine {
    private let speechThreshold: Float
    private let smoother: SpeechStateSmoother
    private let callbackQueue = DispatchQueue(label: "aptune.vad.native")

    private let audioEngine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private var observer: ClassificationObserver?
    private var onSpeechStateChange: ((SpeechState) -> Void)?

    public init(speechThreshold: Float, holdMs: Int, onsetDebounceMs: Int = 60) {
        self.speechThreshold = speechThreshold
        self.smoother = SpeechStateSmoother(onsetDebounceMs: onsetDebounceMs, holdMs: holdMs)
        super.init()
    }

    public func start(onSpeechStateChange: @escaping (SpeechState) -> Void) throws {
        self.onSpeechStateChange = onSpeechStateChange

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let analyzer = SNAudioStreamAnalyzer(format: inputFormat)

        let observer = ClassificationObserver { [weak self] confidence in
            guard let self else { return }
            let timestamp = ProcessInfo.processInfo.systemUptime
            let rawSpeaking = confidence >= self.speechThreshold
            self.callbackQueue.async {
                guard let callback = self.onSpeechStateChange else { return }
                if let state = self.smoother.process(rawSpeaking: rawSpeaking, confidence: confidence, timestamp: timestamp) {
                    callback(state)
                }
            }
        }

        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        try analyzer.add(request, withObserver: observer)

        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak analyzer] buffer, time in
            analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
        }

        self.analyzer = analyzer
        self.observer = observer

        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw VADEngineError.startFailed("Unable to start AVAudioEngine: \(error)")
        }
    }

    public func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        analyzer = nil
        observer = nil
        onSpeechStateChange = nil
        smoother.reset()
    }
}

private final class ClassificationObserver: NSObject, SNResultsObserving {
    private let onConfidence: (Float) -> Void

    init(onConfidence: @escaping (Float) -> Void) {
        self.onConfidence = onConfidence
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else {
            return
        }

        let speechConfidence = result.classifications.first(where: { $0.identifier == "speech" })?.confidence ?? 0
        onConfidence(Float(speechConfidence))
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        fputs("[ERROR] SoundAnalysis failed: \(error)\n", stderr)
    }

    func requestDidComplete(_ request: SNRequest) {}
}

#else

public final class NativeSoundAnalysisEngine: VADEngine {
    public init(speechThreshold: Float, holdMs: Int, onsetDebounceMs: Int = 60) {
        _ = speechThreshold
        _ = holdMs
        _ = onsetDebounceMs
    }

    public func start(onSpeechStateChange: @escaping (SpeechState) -> Void) throws {
        _ = onSpeechStateChange
        throw VADEngineError.unsupported("Native SoundAnalysis VAD is only available on macOS with AVFoundation + SoundAnalysis.")
    }

    public func stop() {}
}

#endif
