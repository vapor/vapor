import XCTest
@testable import Vapor

class CookieTests: XCTestCase {
    static let allTests = [
        ("testInit_setsNameCorrectly", testInit_setsNameCorrectly),
        ("testInit_setsValueCorrectly", testInit_setsValueCorrectly),
        ("testInit_setsExpiresCorrectly", testInit_setsExpiresCorrectly),
        ("testInit_setsMaxAgeCorrectly", testInit_setsMaxAgeCorrectly),
        ("testInit_setsDomainCorrectly", testInit_setsDomainCorrectly),
        ("testInit_setsPathCorrectly", testInit_setsPathCorrectly),
        ("testInit_defaultsToInsecure", testInit_defaultsToInsecure),
        ("testInit_setsSecureCorrectly", testInit_setsSecureCorrectly),
        ("testInit_defaultsToNonHTTPOnly", testInit_defaultsToNonHTTPOnly),
        ("testInit_setsHTTPOnlyCorrectly", testInit_setsHTTPOnlyCorrectly),
        ("testHashValue_usesNamesHash", testHashValue_usesNamesHash),
        ("testEquality_reliesSolelyOnName", testEquality_reliesSolelyOnName)
    ]

    func testInit_setsNameCorrectly() {
        let subject = Cookie(name: "Foo", value: "Bar")
        XCTAssertEqual(subject.name, "Foo")
    }

    func testInit_setsValueCorrectly() {
        let subject = Cookie(name: "Foo", value: "Bar")
        XCTAssertEqual(subject.value, "Bar")
    }

    func testInit_setsExpiresCorrectly() {
        let subject = Cookie(name: "Foo", value: "Bar", expires: "2999-12-30 :23:59:59")
        XCTAssertEqual(subject.expires, "2999-12-30 :23:59:59")
    }

    func testInit_setsMaxAgeCorrectly() {
        let subject = Cookie(name: "Foo", value: "Bar", maxAge: 123456789)
        XCTAssertEqual(subject.maxAge, 123456789)
    }

    func testInit_setsDomainCorrectly() {
        let subject = Cookie(name: "Foo", value: "Bar", domain: "foo.bar.baz")
        XCTAssertEqual(subject.domain, "foo.bar.baz")
    }

    func testInit_setsPathCorrectly() {
        let subject = Cookie(name: "Foo", value: "Bar", path: "/baz")
        XCTAssertEqual(subject.path, "/baz")
    }

    func testInit_defaultsToInsecure() {
        let subject = Cookie(name: "Foo", value: "Bar")
        XCTAssertFalse(subject.secure)
    }

    func testInit_setsSecureCorrectly() {
        let subject = Cookie(name: "Foo", value: "Bar", secure: true)
        XCTAssertTrue(subject.secure)
    }

    func testInit_defaultsToNonHTTPOnly() {
        let subject = Cookie(name: "Foo", value: "Bar")
        XCTAssertFalse(subject.HTTPOnly)
    }

    func testInit_setsHTTPOnlyCorrectly() {
        let subject = Cookie(name: "Foo", value: "Bar", HTTPOnly: true)
        XCTAssertTrue(subject.HTTPOnly)
    }

    func testHashValue_usesNamesHash() {
        let subject = Cookie(name: "Foo", value: "Bar")
        XCTAssertEqual(subject.hashValue, "Foo".hashValue)
    }

    func testEquality_reliesSolelyOnName() {
        let subject1 = Cookie(name: "Foo", value: "Bar")
        let subject2 = Cookie(name: "Baz", value: "Bar")
        let subject3 = Cookie(name: "Foo", value: "Baz")
        XCTAssertEqual(subject1, subject3)
        XCTAssertNotEqual(subject1, subject2)
        XCTAssertNotEqual(subject2, subject3)
    }
}
