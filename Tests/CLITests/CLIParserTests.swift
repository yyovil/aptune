import CLI
import XCTest

final class CLIParserTests: XCTestCase {
    func testParsesDefaultValues() throws {
        let config = try CLIParser.parse(arguments: [])
        XCTAssertEqual(config.downTo, 0.25)
        XCTAssertEqual(config.engine, .native)
        XCTAssertEqual(config.attackMs, 80)
        XCTAssertEqual(config.releaseMs, 600)
        XCTAssertEqual(config.holdMs, 250)
        XCTAssertEqual(config.logLevel, .info)
        XCTAssertEqual(config.speechThreshold, 0.55)
    }

    func testParsesAllFlags() throws {
        let args = [
            "--downTo", "0.4",
            "--engine", "silero",
            "--attack-ms", "100",
            "--release-ms", "700",
            "--hold-ms", "300",
            "--log-level", "debug",
            "--speech-threshold", "0.7"
        ]

        let config = try CLIParser.parse(arguments: args)
        XCTAssertEqual(config.downTo, 0.4)
        XCTAssertEqual(config.engine, .silero)
        XCTAssertEqual(config.attackMs, 100)
        XCTAssertEqual(config.releaseMs, 700)
        XCTAssertEqual(config.holdMs, 300)
        XCTAssertEqual(config.logLevel, .debug)
        XCTAssertEqual(config.speechThreshold, 0.7)
    }

    func testRejectsOutOfRangeDownTo() {
        XCTAssertThrowsError(try CLIParser.parse(arguments: ["--downTo", "1.1"]))
    }

    func testRejectsUnknownFlag() {
        XCTAssertThrowsError(try CLIParser.parse(arguments: ["--bad", "1"]))
    }
}
