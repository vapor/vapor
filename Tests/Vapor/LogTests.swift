import XCTest
@testable import Vapor

/**
 File level to prevent issues w/ linux testing on 04-12 snapshot
 */
private class DummyLogger: Log {

    var output: String
    var enabled: [LogLevel]

    init() {
        output = ""
        enabled = LogLevel.all
    }

    func log(_ level: LogLevel, message: String) {
        output = "\(level.description) \(message)"
    }
}

class LogTests: XCTestCase {
    static let allTests = [
        ("testDummyLogger", testDummyLogger),
    ]

    func testDummyLogger() {
        let log = DummyLogger()
        log.verbose("Hello")

        XCTAssertEqual(log.output, "VERBOSE Hello")

    }
}
