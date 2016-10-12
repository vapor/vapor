import XCTest
@testable import Vapor

/**
 File level to prevent issues w/ linux testing on 04-12 snapshot
 */
private class DummyLogger: LogProtocol {

    var output: String
    var enabled: [LogLevel]

    init() {
        output = ""
        enabled = LogLevel.all
    }
    
    func log(_ level: LogLevel, message: String, file: String, function: String, line: Int) {
        output = "level: \(level.description), message: '\(message)', "
        output += "file: \(file), function: \(function), line: \(line)"
    }
}

class LogTests: XCTestCase {
    static let allTests = [
        ("testDummyLogger", testDummyLogger),
    ]

    func testDummyLogger() {
        let log = DummyLogger()
        log.verbose("Hello")
        
        // is the file, function and source code line of the logging call automatically detected?
        var expectedString = "level: VERBOSE, message: 'Hello', "
        expectedString += "file: \(#file), function: \(#function), line: \((#line - 4))"
        
        XCTAssertEqual(log.output, expectedString)
    }
}
