import XCTest
@testable import Vapor

class HTTPVersionTests: XCTestCase {
    static var allTests = [
        ("testParse", testParse),
        ("testInvalid", testInvalid),
        ("testInvalidMajor", testInvalidMajor),
        ("testInvalidMinor", testInvalidMinor),
    ]

    func testParse() {
        do {
            let version = try makeVersion(with: "HTTP/1.1")
            XCTAssertEqual(version.major, 1)
            XCTAssertEqual(version.major, 1)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testInvalid() {
        do {
            _ = try makeVersion(with: "ferrets")
            XCTFail("init should have thrown")
        } catch HTTPRequestParser.Error.invalidVersion {
            //
        } catch {
            XCTFail("Wrong error")
        }
    }

    func testInvalidMajor() {
        do {
            _ = try makeVersion(with: "HTTP/ferret.0")
            XCTFail("init should have thrown")
        } catch HTTPRequestParser.Error.invalidVersionMajor {
            //
        } catch {
            XCTFail("Wrong error")
        }
    }

    func testInvalidMinor() {
        do {
            _ = try makeVersion(with: "HTTP/1.f")
            XCTFail("init should have thrown")
        } catch HTTPRequestParser.Error.invalidVersionMinor {
            //
        } catch {
            XCTFail("Wrong error")
        }
    }

    private func makeVersion(with versionString: String) throws -> Version {
        let stream = TestStream()
        let parser = HTTPRequestParser(stream: stream)
        return try parser.parseVersion(versionString.bytesSlice)
    }
}
