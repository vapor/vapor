import XCTest
@testable import Vapor

extension Version {
    init(_ string: String) throws {
        try self.init(string.bytesSlice)
    }
}

class HTTPVersionTests: XCTestCase {
    static var allTests = [
        ("testParse", testParse),
        ("testInvalid", testInvalid),
        ("testInvalidMajor", testInvalidMajor),
        ("testInvalidMinor", testInvalidMinor),
    ]

    func testParse() {
        do {
            let version = try Version("HTTP/1.1")
            XCTAssertEqual(version.major, 1)
            XCTAssertEqual(version.major, 1)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testInvalid() {
        do {
            _ = try Version("ferrets")
            XCTFail("init should have thrown")
        } catch Version.Error.invalid {
            //
        } catch {
            XCTFail("Wrong error")
        }
    }

    func testInvalidMajor() {
        do {
            _ = try Version("HTTP/ferret.0")
            XCTFail("init should have thrown")
        } catch Version.Error.invalidMajor {
            //
        } catch {
            XCTFail("Wrong error")
        }
    }

    func testInvalidMinor() {
        do {
            _ = try Version("HTTP/1.f")
            XCTFail("init should have thrown")
        } catch Version.Error.invalidMinor {
            //
        } catch {
            XCTFail("Wrong error")
        }
    }
}
