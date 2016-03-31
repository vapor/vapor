//
//  MemorySessionDriverTests.swift
//  Vapor
//
//  Created by James Richard on 3/4/16.
//

import XCTest
@testable import Vapor

class MemorySessionDriverTests: XCTestCase {
    var application = Application()

    var identifier = "baz"
    static var allTests: [(String, MemorySessionDriverTests -> () throws -> Void)] {
        return [
           ("testValueForKey_onNonExistantSession_isNil", testValueForKey_onNonExistantSession_isNil),
           ("testValueForKey_onExistingSession_onNonExistingKey_isNil", testValueForKey_onExistingSession_onNonExistingKey_isNil),
           ("testValueForKey_onExistingSession_onExistingKey_isKeyValue", testValueForKey_onExistingSession_onExistingKey_isKeyValue),
           ("testSetValueForKey_setsValueCorrectly", testSetValueForKey_setsValueCorrectly),
           ("testSetValueForKey_withExistingValue_overwritesValueCorrectly", testSetValueForKey_withExistingValue_overwritesValueCorrectly),
           ("testSetValueForKey_withExistingValue_toNilErasesValue", testSetValueForKey_withExistingValue_toNilErasesValue),
           ("testDestroySession_removesSession", testDestroySession_removesSession)
        ]
    }

    // MARK: - Obtaining Values
    func testValueForKey_onNonExistantSession_isNil() {
        let subject = MemorySessionDriver(application: application)
        _ = Session(identifier: identifier, driver: subject)
        XCTAssertNil(subject.valueFor(key: "foo", identifier: identifier))
    }

    func testValueForKey_onExistingSession_onNonExistingKey_isNil() {
        let subject = MemorySessionDriver(application: application)
        _ = Session(identifier: identifier, driver: subject)
        subject.sessions = ["baz": [:]]
        XCTAssertNil(subject.valueFor(key: "foo", identifier: identifier))
    }

    func testValueForKey_onExistingSession_onExistingKey_isKeyValue() {
        let subject = MemorySessionDriver(application: application)
        _ = Session(identifier: identifier, driver: subject)
        subject.sessions = ["baz": ["foo":"bar"]]
        XCTAssertEqual(subject.valueFor(key: "foo", identifier: identifier), "bar")
    }

    // MARK: - Setting Values
    func testSetValueForKey_setsValueCorrectly() {
        let subject = MemorySessionDriver(application: application)
        let _ = Session(identifier: identifier, driver: subject)
        subject.set("foo", forKey: "bar", identifier: identifier)
        XCTAssertEqual(subject.sessions["baz"]?["bar"], "foo")
    }

    func testSetValueForKey_withExistingValue_overwritesValueCorrectly() {
        let subject = MemorySessionDriver(application: application)
        let _ = Session(identifier: identifier, driver: subject)
        subject.sessions = ["baz":["bar":"foo"]]
        subject.set("frob", forKey: "bar", identifier: identifier)
        XCTAssertEqual(subject.sessions["baz"]?["bar"], "frob")
    }

    func testSetValueForKey_withExistingValue_toNilErasesValue() {
        let subject = MemorySessionDriver(application: application)
        let _ = Session(identifier: identifier, driver: subject)
        subject.sessions = ["baz":["bar":"foo"]]
        subject.set(nil, forKey: "bar", identifier: identifier)
        XCTAssertNil(subject.sessions["baz"]?["bar"])
    }

    // MARK: - Destroying

    func testDestroySession_removesSession() {
        let subject = MemorySessionDriver(application: application)
        subject.sessions = ["baz":["bar":"foo"], "frob": [:]]
        let _ = Session(identifier: identifier, driver: subject)
        subject.destroy(identifier)

        guard subject.sessions["frob"] != nil else {
            XCTFail("Session was unexpectedly removed")
            return
        }

        XCTAssertEqual(subject.sessions["frob"]!, [String: String]())
    }
}
