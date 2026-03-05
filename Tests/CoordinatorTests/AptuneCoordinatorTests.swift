import CLI
import Coordinator
import VAD
import VolumeControl
import XCTest

final class AptuneCoordinatorTests: XCTestCase {
    func testOnsetDucksOnceAndSustainDoesNotReduck() throws {
        let config = try AptuneConfig(downTo: 0.3)
        let mock = MockVolumeDucker()
        let logger = Logger(level: .debug)
        let coordinator = AptuneCoordinator(config: config, volumeDucker: mock, logger: logger)

        coordinator.handleSpeechState(SpeechState(isSpeaking: true, confidence: 0.8, timestamp: 0))
        coordinator.handleSpeechState(SpeechState(isSpeaking: true, confidence: 0.9, timestamp: 1))
        usleep(50_000)

        XCTAssertEqual(mock.duckCalls.count, 1)
        XCTAssertEqual(mock.restoreCalls.count, 0)
    }

    func testReleaseRestoresOnce() throws {
        let config = try AptuneConfig(downTo: 0.3, releaseMs: 750)
        let mock = MockVolumeDucker()
        let logger = Logger(level: .info)
        let coordinator = AptuneCoordinator(config: config, volumeDucker: mock, logger: logger)

        coordinator.handleSpeechState(SpeechState(isSpeaking: true, confidence: 0.8, timestamp: 0))
        coordinator.handleSpeechState(SpeechState(isSpeaking: false, confidence: 0.3, timestamp: 1))
        usleep(50_000)

        XCTAssertEqual(mock.duckCalls.count, 1)
        XCTAssertEqual(mock.restoreCalls, [750])
    }

    func testShutdownRestores() throws {
        let config = try AptuneConfig()
        let mock = MockVolumeDucker()
        let logger = Logger(level: .info)
        let coordinator = AptuneCoordinator(config: config, volumeDucker: mock, logger: logger)

        coordinator.shutdown()
        XCTAssertTrue(mock.stopAndRestoreCalled)
    }
}

private final class MockVolumeDucker: VolumeDucking {
    private(set) var duckCalls: [(downTo: Double, attackMs: Int)] = []
    private(set) var restoreCalls: [Int] = []
    private(set) var stopAndRestoreCalled = false

    func duck(to downTo: Double, attackMs: Int) {
        duckCalls.append((downTo, attackMs))
    }

    func restore(releaseMs: Int) {
        restoreCalls.append(releaseMs)
    }

    func stopAndRestore() {
        stopAndRestoreCalled = true
    }
}
