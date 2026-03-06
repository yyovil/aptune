@testable import VAD
import XCTest

final class FireRedSpeechGateTests: XCTestCase {
    func testCalibrationSuppressesSpeaking() {
        let gate = FireRedSpeechGate(
            speechThreshold: 0.7,
            calibrationFrameCount: 3
        )

        XCTAssertFalse(gate.process(probability: 0.99, levelDb: -20).rawSpeaking)
        XCTAssertFalse(gate.process(probability: 0.99, levelDb: -20).rawSpeaking)
        XCTAssertFalse(gate.process(probability: 0.99, levelDb: -20).rawSpeaking)
    }

    func testMusicLikeLevelRiseDecaysBeforeSmootherWouldTrigger() {
        let gate = FireRedSpeechGate(
            speechThreshold: 0.7,
            activationProbabilityFloor: 0.9,
            activationLevelDeltaDb: 8,
            activationAbsoluteLevelDb: -39,
            sustainAbsoluteLevelDb: -43,
            ambientRiseAlpha: 0.12,
            ambientFallAlpha: 0.04,
            calibrationFrameCount: 0
        )
        let smoother = SpeechStateSmoother(onsetDebounceMs: 80, holdMs: 250)

        for _ in 0..<30 {
            let result = gate.process(probability: 0.05, levelDb: -46)
            _ = smoother.process(rawSpeaking: result.rawSpeaking, confidence: 0.05, timestamp: 0)
        }

        var state: SpeechState?
        for frame in 0..<10 {
            let timestamp = TimeInterval(frame) * 0.01
            let result = gate.process(probability: 0.85, levelDb: -34)
            state = smoother.process(rawSpeaking: result.rawSpeaking, confidence: 0.99, timestamp: timestamp)
        }

        XCTAssertNil(state)
    }

    func testNearFieldSpeechCandidateSustainsLongEnoughToTrigger() {
        let gate = FireRedSpeechGate(
            speechThreshold: 0.7,
            activationProbabilityFloor: 0.9,
            activationLevelDeltaDb: 8,
            activationAbsoluteLevelDb: -39,
            sustainAbsoluteLevelDb: -43,
            ambientRiseAlpha: 0.12,
            ambientFallAlpha: 0.04,
            calibrationFrameCount: 0
        )
        let smoother = SpeechStateSmoother(onsetDebounceMs: 60, holdMs: 250)

        for _ in 0..<30 {
            let result = gate.process(probability: 0.05, levelDb: -46)
            _ = smoother.process(rawSpeaking: result.rawSpeaking, confidence: 0.05, timestamp: 0)
        }

        var events: [Bool] = []
        let frames: [(Float, Float)] = [
            (0.96, -36),
            (0.84, -38),
            (0.82, -39),
            (0.81, -39),
            (0.80, -39),
            (0.78, -40),
            (0.75, -40),
            (0.72, -41)
        ]

        for (frame, sample) in frames.enumerated() {
            let timestamp = TimeInterval(frame) * 0.01
            let result = gate.process(probability: sample.0, levelDb: sample.1)
            if let state = smoother.process(rawSpeaking: result.rawSpeaking, confidence: 0.99, timestamp: timestamp) {
                events.append(state.isSpeaking)
            }
        }

        XCTAssertEqual(events, [true])
    }

    func testResetClearsCandidateState() {
        let gate = FireRedSpeechGate(speechThreshold: 0.7, calibrationFrameCount: 0)

        _ = gate.process(probability: 0.05, levelDb: -46)
        _ = gate.process(probability: 0.96, levelDb: -36)
        XCTAssertTrue(gate.candidateActive)

        gate.reset()

        XCTAssertFalse(gate.candidateActive)
        XCTAssertNil(gate.ambientLevelDb)
    }
}
