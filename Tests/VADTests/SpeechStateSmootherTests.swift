import VAD
import XCTest

final class SpeechStateSmootherTests: XCTestCase {
    func testDebouncesSpeechOnset() {
        let smoother = SpeechStateSmoother(onsetDebounceMs: 60, holdMs: 250)

        XCTAssertNil(smoother.process(rawSpeaking: true, confidence: 0.8, timestamp: 0.00))
        XCTAssertNil(smoother.process(rawSpeaking: true, confidence: 0.8, timestamp: 0.04))

        let state = smoother.process(rawSpeaking: true, confidence: 0.8, timestamp: 0.07)
        XCTAssertEqual(state?.isSpeaking, true)
    }

    func testAppliesReleaseHold() {
        let smoother = SpeechStateSmoother(onsetDebounceMs: 60, holdMs: 250)

        _ = smoother.process(rawSpeaking: true, confidence: 0.8, timestamp: 0.00)
        _ = smoother.process(rawSpeaking: true, confidence: 0.8, timestamp: 0.07)

        XCTAssertNil(smoother.process(rawSpeaking: false, confidence: 0.2, timestamp: 0.10))
        XCTAssertNil(smoother.process(rawSpeaking: false, confidence: 0.2, timestamp: 0.30))

        let state = smoother.process(rawSpeaking: false, confidence: 0.2, timestamp: 0.36)
        XCTAssertEqual(state?.isSpeaking, false)
    }

    func testNoChatterOnMixedFrames() {
        let smoother = SpeechStateSmoother(onsetDebounceMs: 60, holdMs: 250)

        var events: [Bool] = []
        let frames: [(Bool, TimeInterval)] = [
            (true, 0.00),
            (false, 0.03),
            (true, 0.06),
            (true, 0.13),
            (false, 0.20),
            (true, 0.22),
            (false, 0.26),
            (false, 0.52)
        ]

        for frame in frames {
            if let state = smoother.process(rawSpeaking: frame.0, confidence: 0.7, timestamp: frame.1) {
                events.append(state.isSpeaking)
            }
        }

        XCTAssertEqual(events, [true, false])
    }
}
