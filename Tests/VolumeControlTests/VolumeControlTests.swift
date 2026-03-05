import VolumeControl
import XCTest

final class VolumeRampPlannerTests: XCTestCase {
    func testPlanReturnsSingleValueForZeroDuration() {
        let values = VolumeRampPlanner.plan(from: 0.9, to: 0.2, durationMs: 0)
        XCTAssertEqual(values, [0.2])
    }

    func testPlanClampsAndSteps() {
        let values = VolumeRampPlanner.plan(from: 1.2, to: -0.5, durationMs: 100, stepMs: 20)
        XCTAssertEqual(values.count, 5)
        XCTAssertEqual(values.first ?? -1, 0.8, accuracy: 0.0001)
        XCTAssertEqual(values.last ?? -1, 0.0, accuracy: 0.0001)
    }
}

final class VolumeDuckerTests: XCTestCase {
    func testDuckCapturesBaselineOnlyOnce() {
        let controller = MockVolumeController(initial: 0.8)
        let ducker = VolumeDucker(controller: controller)

        ducker.duck(to: 0.25, attackMs: 0)
        ducker.duck(to: 0.20, attackMs: 0)
        usleep(100_000)

        XCTAssertEqual(controller.getCalls, 3)
        XCTAssertEqual(controller.setHistory.last ?? -1, 0.2, accuracy: 0.0001)
    }

    func testRestoreReturnsToOriginalBaseline() {
        let controller = MockVolumeController(initial: 0.7)
        let ducker = VolumeDucker(controller: controller)

        ducker.duck(to: 0.3, attackMs: 0)
        usleep(40_000)
        ducker.restore(releaseMs: 0)
        usleep(40_000)

        XCTAssertEqual(controller.setHistory.last ?? -1, 0.7, accuracy: 0.0001)
    }
}

private final class MockVolumeController: SystemVolumeControlling {
    private var current: Double
    private(set) var getCalls = 0
    private(set) var setHistory: [Double] = []

    init(initial: Double) {
        self.current = initial
    }

    func getCurrentVolume() throws -> Double {
        getCalls += 1
        return current
    }

    func setVolume(_ fraction: Double) throws {
        current = fraction
        setHistory.append(fraction)
    }
}
