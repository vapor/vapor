import XCTest
@testable import Vapor

class ProcessTests: XCTestCase {

    static let allTests = [
        ("testArgumentExtraction", testArgumentExtraction),
        ("testFixes", testFixes)
    ]

    func testArgumentExtraction() {
        let testArguments = ["--ip=123.45.1.6", "--port=8080", "--workDir=WorkDirectory"]

        let ip = testArguments.value(for: "ip")
        XCTAssert(ip == "123.45.1.6")

        let port = testArguments.value(for: "port")
        XCTAssert(port == "8080")

        let workDir = testArguments.value(for: "workDir")
        XCTAssert(workDir == "WorkDirectory")
    }

    func testFixes() {
        let bytes: [UInt8] = [64, 64, 64]
        let string = bytes.string
        XCTAssert(string == "@@@")
    }
}
