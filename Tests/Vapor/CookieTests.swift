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
        ("testEquality_reliesSolelyOnName", testEquality_reliesSolelyOnName),
        ("testSerialize_producesExpectedOutput", testSerialize_producesExpectedOutput)
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
        let subject = Cookie(name: "Foo", value: "Bar", expires: "Wed, 20 Jul 2016 13:20:15 GMT")
        XCTAssertEqual(subject.expires, "Wed, 20 Jul 2016 13:20:15 GMT")
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

    func testSerialize_producesExpectedOutput() {
        var subject = Cookie(name: "Foo", value: "Bar")
        XCTAssertEqual(subject.serialize(), "Foo=Bar")
        subject.expires = "Wed, 20 Jul 2016 09:00:15 GMT"
        XCTAssertEqual(subject.serialize(), "Foo=Bar; Expires=Wed, 20 Jul 2016 09:00:15 GMT")
        subject.path = "/bar/food/yum"
        XCTAssertEqual(subject.serialize(), "Foo=Bar; Expires=Wed, 20 Jul 2016 09:00:15 GMT; Path=/bar/food/yum")
        subject.domain = "vapor.qutheory.io"
        XCTAssertEqual(subject.serialize(), "Foo=Bar; Expires=Wed, 20 Jul 2016 09:00:15 GMT; Domain=vapor.qutheory.io; Path=/bar/food/yum")
        subject.maxAge = 600
        XCTAssertEqual(subject.serialize(), "Foo=Bar; Expires=Wed, 20 Jul 2016 09:00:15 GMT; Max-Age=600; Domain=vapor.qutheory.io; Path=/bar/food/yum")
        subject.secure = true
        XCTAssertEqual(subject.serialize(), "Foo=Bar; Expires=Wed, 20 Jul 2016 09:00:15 GMT; Max-Age=600; Domain=vapor.qutheory.io; Path=/bar/food/yum; Secure")
        subject.HTTPOnly = true
        XCTAssertEqual(subject.serialize(), "Foo=Bar; Expires=Wed, 20 Jul 2016 09:00:15 GMT; Max-Age=600; Domain=vapor.qutheory.io; Path=/bar/food/yum; Secure; HttpOnly")
    }
}
