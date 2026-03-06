import Foundation

#if os(macOS) && canImport(AVFoundation) && canImport(CoreML) && canImport(Accelerate)
import Accelerate
import AVFoundation
import CoreML

public final class FireRedEngine: VADEngine {
    private let smoother: SpeechStateSmoother
    private let callbackQueue = DispatchQueue(label: "aptune.vad.firered.callback")
    private let analysisQueue = DispatchQueue(label: "aptune.vad.firered.analysis")

    private let audioEngine = AVAudioEngine()
    private var onSpeechStateChange: ((SpeechState) -> Void)?
    private var resampler: FireRedAudioResampler?
    private var featureExtractor = FireRedFeatureExtractor()
    private var inferencer: FireRedCoreMLInferencer?
    private var speechGate: FireRedSpeechGate
    private let debugEnabled = ProcessInfo.processInfo.environment["APTUNE_FIRERED_DEBUG"] == "1"
    private var debugFrameCount = 0

    public init(speechThreshold: Float, holdMs: Int, onsetDebounceMs: Int = 60) {
        self.smoother = SpeechStateSmoother(onsetDebounceMs: onsetDebounceMs, holdMs: holdMs)
        self.speechGate = FireRedSpeechGate(speechThreshold: speechThreshold)
    }

    public func start(onSpeechStateChange: @escaping (SpeechState) -> Void) throws {
        self.onSpeechStateChange = onSpeechStateChange

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let resampler = try FireRedAudioResampler(inputFormat: inputFormat)
        let inferencer = try FireRedCoreMLInferencer()

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.analysisQueue.async {
                self.process(buffer: buffer)
            }
        }

        self.resampler = resampler
        self.inferencer = inferencer

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            stop()
            throw VADEngineError.startFailed("Unable to start FireRedVAD audio capture: \(error)")
        }
    }

    public func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        analysisQueue.sync {
            inferencer = nil
            resampler = nil
            featureExtractor.reset()
            speechGate.reset()
            debugFrameCount = 0
        }

        onSpeechStateChange = nil
        smoother.reset()
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let resampler, let inferencer else { return }

        do {
            let samples = try resampler.convert(buffer: buffer)
            let observations = try featureExtractor.append(samples: samples)
            for observation in observations {
                let probability = try inferencer.predict(feature: observation.feature)
                let gateResult = speechGate.process(probability: probability, levelDb: observation.levelDb)
                debug(probability: probability, levelDb: observation.levelDb, gateResult: gateResult)
                handle(probability: probability, rawSpeaking: gateResult.rawSpeaking)
            }
        } catch {
            fputs("[ERROR] FireRedVAD processing failed: \(error)\n", stderr)
        }
    }

    private func handle(probability: Float, rawSpeaking: Bool) {
        let timestamp = ProcessInfo.processInfo.systemUptime

        callbackQueue.async {
            guard let callback = self.onSpeechStateChange else { return }
            if let state = self.smoother.process(rawSpeaking: rawSpeaking, confidence: probability, timestamp: timestamp) {
                callback(state)
            }
        }
    }

    private func debug(probability: Float, levelDb: Float, gateResult: FireRedSpeechGateResult) {
        guard debugEnabled else { return }
        debugFrameCount += 1
        if debugFrameCount % 25 == 0 {
            let ambient = gateResult.ambientLevelDb ?? .nan
            fputs("[DEBUG] FireRed frame=\(debugFrameCount) probability=\(probability) levelDb=\(levelDb) ambientDb=\(ambient) deltaDb=\(gateResult.deltaDb) calibrationFrames=\(gateResult.remainingCalibrationFrames) candidateActive=\(gateResult.candidateActive) rawSpeaking=\(gateResult.rawSpeaking)\n", stderr)
        }
    }
}

private struct FireRedFrameObservation {
    let feature: [Float]
    let levelDb: Float
}

private final class FireRedAudioResampler {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat

    init(inputFormat: AVAudioFormat) throws {
        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw VADEngineError.startFailed("Unable to create FireRedVAD audio converter for 16 kHz mono input.")
        }

        self.converter = converter
        self.outputFormat = outputFormat
    }

    func convert(buffer: AVAudioPCMBuffer) throws -> [Float] {
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * outputFormat.sampleRate / buffer.format.sampleRate).rounded(.up)) + 32
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw VADEngineError.startFailed("Unable to allocate FireRedVAD resample buffer.")
        }

        var consumedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if consumedInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            consumedInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let conversionError {
            throw VADEngineError.startFailed("FireRedVAD audio conversion failed: \(conversionError)")
        }

        switch status {
        case .haveData, .inputRanDry, .endOfStream:
            break
        case .error:
            throw VADEngineError.startFailed("FireRedVAD audio conversion ended with an unknown error.")
        @unknown default:
            throw VADEngineError.startFailed("FireRedVAD audio conversion returned an unsupported status.")
        }

        guard let channelData = outputBuffer.floatChannelData else {
            return []
        }

        let frameCount = Int(outputBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
    }
}

private struct FireRedFeatureExtractor {
    private static let sampleRate = 16_000
    private static let frameLength = 400
    private static let frameShift = 160
    private static let fftSize = 512
    private static let melBins = 80
    private static let fftBins = Self.fftSize / 2 + 1
    private static let eps: Float = 1e-10

    private var pending: [Float] = []
    private let window: [Float]
    private let melFilters: [[Float]]
    private let fft: vDSP.DiscreteFourierTransform<Float>
    private let means = FireRedCMVN.means
    private let invstd = FireRedCMVN.invstd

    init() {
        self.window = Self.makePoveyWindow(length: Self.frameLength)
        self.melFilters = Self.makeMelFilterBank()
        guard let fft = try? vDSP.DiscreteFourierTransform<Float>(
            count: Self.fftSize,
            direction: .forward,
            transformType: .complexComplex,
            ofType: Float.self
        ) else {
            fatalError("Unable to create FireRed FFT setup.")
        }
        self.fft = fft
    }

    mutating func append(samples: [Float]) throws -> [FireRedFrameObservation] {
        guard !samples.isEmpty else { return [] }
        pending.append(contentsOf: samples)

        var features: [FireRedFrameObservation] = []
        while pending.count >= Self.frameLength {
            let frame = Array(pending.prefix(Self.frameLength))
            let levelDb = Self.computeLevelDb(frame: frame)
            features.append(FireRedFrameObservation(feature: computeFeature(frame: frame), levelDb: levelDb))
            pending.removeFirst(Self.frameShift)
        }

        return features
    }

    mutating func reset() {
        pending.removeAll(keepingCapacity: false)
    }

    private func computeFeature(frame: [Float]) -> [Float] {
        let scaledFrame = frame.map { $0 * Float(Int16.max) }
        let mean = scaledFrame.reduce(0, +) / Float(scaledFrame.count)
        var emphasized = [Float](repeating: 0, count: Self.frameLength)
        for index in 0..<Self.frameLength {
            let centered = scaledFrame[index] - mean
            let previous = index == 0 ? centered : (scaledFrame[index - 1] - mean)
            emphasized[index] = index == 0 ? centered : centered - 0.97 * previous
        }

        var padded = [Float](repeating: 0, count: Self.fftSize)
        for index in 0..<Self.frameLength {
            padded[index] = emphasized[index] * window[index]
        }

        let imagInput = [Float](repeating: 0, count: Self.fftSize)
        let transformed = fft.transform(real: padded, imaginary: imagInput)
        let real = transformed.real
        let imag = transformed.imaginary

        var spectrum = [Float](repeating: 0, count: Self.fftBins)
        for index in 0..<Self.fftBins {
            spectrum[index] = real[index] * real[index] + imag[index] * imag[index]
        }

        var feature = [Float](repeating: 0, count: Self.melBins)
        for melIndex in 0..<Self.melBins {
            var energy: Float = 0
            for bin in 0..<Self.fftBins {
                energy += melFilters[melIndex][bin] * spectrum[bin]
            }
            let logEnergy = log(max(energy, Self.eps))
            feature[melIndex] = (logEnergy - means[melIndex]) * invstd[melIndex]
        }

        return feature
    }

    private static func makePoveyWindow(length: Int) -> [Float] {
        guard length > 1 else { return [1] }
        return (0..<length).map { index in
            let phase = (2 * Float.pi * Float(index)) / Float(length - 1)
            return pow(0.5 - 0.5 * cos(phase), 0.85)
        }
    }

    private static func makeMelFilterBank() -> [[Float]] {
        let lowMel = hzToMel(20)
        let highMel = hzToMel(Float(Self.sampleRate) / 2)
        let melPoints = (0..<(Self.melBins + 2)).map { index in
            lowMel + (Float(index) * (highMel - lowMel) / Float(Self.melBins + 1))
        }
        let hzPoints = melPoints.map(melToHz)
        let binFrequencies = (0..<Self.fftBins).map { index in
            Float(index) * Float(Self.sampleRate) / Float(Self.fftSize)
        }

        return (0..<Self.melBins).map { filterIndex in
            let left = hzPoints[filterIndex]
            let center = hzPoints[filterIndex + 1]
            let right = hzPoints[filterIndex + 2]
            return binFrequencies.map { frequency in
                if frequency < left || frequency > right {
                    return 0
                } else if frequency <= center {
                    return (frequency - left) / max(center - left, Self.eps)
                } else {
                    return (right - frequency) / max(right - center, Self.eps)
                }
            }
        }
    }

    private static func hzToMel(_ hz: Float) -> Float {
        1127 * log(1 + hz / 700)
    }

    private static func melToHz(_ mel: Float) -> Float {
        700 * (exp(mel / 1127) - 1)
    }

    private static func computeLevelDb(frame: [Float]) -> Float {
        let sumSquares = frame.reduce(Float.zero) { partial, sample in
            partial + sample * sample
        }
        let rms = sqrt(sumSquares / Float(max(frame.count, 1)))
        return 20 * log10(max(rms, 1e-6))
    }
}

private enum FireRedCMVN {
    static let means: [Float] = [
        10.42295175, 10.86209741, 11.76454438, 12.4901647, 13.25983008, 13.89594383, 14.36494024, 14.59394835,
        14.7497236, 14.66831535, 14.73079672, 14.77505246, 14.98905198, 15.17800493, 15.25352031, 15.32863705,
        15.33401859, 15.2886417, 15.42766169, 15.24626616, 15.0925738, 15.29042194, 15.07575009, 15.18677287,
        15.08867324, 15.1707974, 15.07017809, 15.15079534, 15.10853283, 15.11534508, 15.14127999, 15.13183236,
        15.14519587, 15.19151893, 15.23547867, 15.30636975, 15.37302148, 15.41639463, 15.45985744, 15.39143273,
        15.46357624, 15.39966121, 15.46290792, 15.44162912, 15.48496953, 15.55240178, 15.63809193, 15.70548935,
        15.76700885, 15.85512378, 15.86726978, 15.89153741, 15.92314483, 15.97838261, 16.01480167, 16.04867494,
        16.08202991, 16.09680075, 16.09373669, 16.0724792, 16.07550966, 16.02227088, 15.9767621, 15.89786455,
        15.81274164, 15.71120511, 15.60419889, 15.55351944, 15.51025275, 15.46002382, 15.41568436, 15.37602765,
        15.32834898, 15.2953708, 15.18547019, 15.01704498, 14.90508003, 14.62380657, 14.13809381, 13.31387035
    ]

    static let invstd: [Float] = [
        0.24949809, 0.23563235, 0.23145153, 0.23322339, 0.2318266, 0.22853357, 0.2243487, 0.2189892,
        0.21832438, 0.22082593, 0.22296736, 0.22288416, 0.22234811, 0.22100642, 0.21994202, 0.22005444,
        0.22070092, 0.2215081, 0.22236667, 0.22305292, 0.22335342, 0.22438906, 0.22547702, 0.22690076,
        0.22823023, 0.22931472, 0.23046728, 0.23083553, 0.23143383, 0.23220659, 0.23257989, 0.2336197,
        0.23437241, 0.23508253, 0.23578079, 0.235892, 0.23602098, 0.236638, 0.23749876, 0.23798452,
        0.23899378, 0.23974815, 0.24030836, 0.24097694, 0.24143249, 0.24135466, 0.24079938, 0.24047405,
        0.23995525, 0.23952288, 0.23948089, 0.23936509, 0.23929339, 0.23902199, 0.23857873, 0.23814702,
        0.23804621, 0.23824194, 0.23860095, 0.23915407, 0.23922541, 0.23938308, 0.2397336, 0.23960562,
        0.24028503, 0.24061813, 0.2406793, 0.24096202, 0.24043606, 0.24021527, 0.23972514, 0.23871998,
        0.23744131, 0.23619509, 0.23337281, 0.22680233, 0.22577503, 0.22503847, 0.22631137, 0.22899493
    ]
}

private final class FireRedCoreMLInferencer {
    private let model: MLModel
    private var caches: [MLMultiArray]

    init() throws {
        let modelURL = try Self.resolveModelURL()
        let compiledURL = try MLModel.compileModel(at: modelURL)
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        self.model = try MLModel(contentsOf: compiledURL, configuration: configuration)
        self.caches = try (0..<8).map { _ in
            let cache = try MLMultiArray(shape: [1, 128, 19], dataType: .float32)
            for index in 0..<cache.count {
                cache[index] = 0
            }
            return cache
        }
    }

    func predict(feature: [Float]) throws -> Float {
        let featArray = try MLMultiArray(shape: [1, 1, 80], dataType: .float32)
        for (index, value) in feature.enumerated() {
            featArray[index] = NSNumber(value: value)
        }

        var inputs: [String: MLFeatureValue] = ["feat": MLFeatureValue(multiArray: featArray)]
        for index in 0..<caches.count {
            inputs["cache_\(index)"] = MLFeatureValue(multiArray: caches[index])
        }

        let provider = try MLDictionaryFeatureProvider(dictionary: inputs)
        let prediction = try model.prediction(from: provider)

        guard let probs = prediction.featureValue(for: "probs")?.multiArrayValue else {
            throw VADEngineError.startFailed("FireRedVAD Core ML output 'probs' is missing.")
        }

        for index in 0..<caches.count {
            guard let cache = prediction.featureValue(for: "new_cache_\(index)")?.multiArrayValue else {
                throw VADEngineError.startFailed("FireRedVAD Core ML output 'new_cache_\(index)' is missing.")
            }
            caches[index] = cache
        }

        return probs[0].floatValue
    }

    private static func resolveModelURL() throws -> URL {
        guard let url = Bundle.module.url(forResource: "FireRedVAD", withExtension: "mlpackage") else {
            throw VADEngineError.startFailed("FireRedVAD Core ML package is missing from the VAD module resources.")
        }
        return url
    }
}

#else

public final class FireRedEngine: VADEngine {
    public init(speechThreshold: Float, holdMs: Int, onsetDebounceMs: Int = 120) {
        _ = speechThreshold
        _ = holdMs
        _ = onsetDebounceMs
    }

    public func start(onSpeechStateChange: @escaping (SpeechState) -> Void) throws {
        _ = onSpeechStateChange
        throw VADEngineError.unsupported("FireRedVAD is only available on macOS with AVFoundation, CoreML, and Accelerate.")
    }

    public func stop() {}
}

#endif
