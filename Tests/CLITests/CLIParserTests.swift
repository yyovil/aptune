import CLI
import XCTest

final class CLIParserTests: XCTestCase {
    func testParsesDefaultValues() throws {
        let command = try CLIParser.parse(arguments: [])
        guard case .run(let config) = command else {
            return XCTFail("Expected run command")
        }
        XCTAssertEqual(config.downTo, 0.25)
        XCTAssertEqual(config.attackMs, 80)
        XCTAssertEqual(config.releaseMs, 600)
        XCTAssertEqual(config.holdMs, 250)
        XCTAssertEqual(config.logLevel, .info)
        XCTAssertEqual(config.speechThreshold, 0.7)
    }

    func testParsesAllFlags() throws {
        let args = [
            "--downTo", "0.4",
            "--attack-ms", "100",
            "--release-ms", "700",
            "--hold-ms", "300",
            "--log-level", "debug",
            "--speech-threshold", "0.8"
        ]

        let command = try CLIParser.parse(arguments: args)
        guard case .run(let config) = command else {
            return XCTFail("Expected run command")
        }

        XCTAssertEqual(config.downTo, 0.4)
        XCTAssertEqual(config.attackMs, 100)
        XCTAssertEqual(config.releaseMs, 700)
        XCTAssertEqual(config.holdMs, 300)
        XCTAssertEqual(config.logLevel, .debug)
        XCTAssertEqual(config.speechThreshold, 0.8)
    }

    func testRejectsOutOfRangeDownTo() {
        XCTAssertThrowsError(try CLIParser.parse(arguments: ["--downTo", "1.1"]))
    }

    func testRejectsUnknownFlag() {
        XCTAssertThrowsError(try CLIParser.parse(arguments: ["--bad", "1"]))
    }

    func testRejectsRemovedEngineFlag() {
        XCTAssertThrowsError(try CLIParser.parse(arguments: ["--engine", "firered"]))
    }

    func testShowsVersionForLongAndShortFlags() throws {
        XCTAssertEqual(try CLIParser.parse(arguments: ["--version"]), .showVersion)
        XCTAssertEqual(try CLIParser.parse(arguments: ["-v"]), .showVersion)
        XCTAssertEqual(try CLIParser.parse(arguments: ["version"]), .showVersion)
    }

    func testShowsHelpForLongAndShortFlags() throws {
        XCTAssertEqual(try CLIParser.parse(arguments: ["--help"]), .showHelp)
        XCTAssertEqual(try CLIParser.parse(arguments: ["-h"]), .showHelp)
        XCTAssertEqual(try CLIParser.parse(arguments: ["help"]), .showHelp)
    }
}
