//
//  MemorySessionDriverTests.swift
//  Vapor
//
//  Created by James Richard on 3/4/16.
//

import XCTest
@testable import Vapor

/**
 Working around linux testing bug
 */
private class MSDTHelper {
    static var application = Application()
    static var identifier = "baz"
}

class MemorySessionDriverTests: XCTestCase {
    static var allTests: [(String, (MemorySessionDriverTests) -> () throws -> Void)] {
        return [
            ("testValueForKey_onNonExistantSession_isNil",
                testValueForKey_onNonExistantSession_isNil),
            ("testValueForKey_onExistingSession_onNonExistingKey_isNil",
                testValueForKey_onExistingSession_onNonExistingKey_isNil),
            ("testValueForKey_onExistingSession_onExistingKey_isKeyValue",
                testValueForKey_onExistingSession_onExistingKey_isKeyValue),
            ("testSetValueForKey_setsValueCorrectly",
                testSetValueForKey_setsValueCorrectly),
            ("testSetValueForKey_withExistingValue_overwritesValueCorrectly",
                testSetValueForKey_withExistingValue_overwritesValueCorrectly),
            ("testSetValueForKey_withExistingValue_toNilErasesValue",
                testSetValueForKey_withExistingValue_toNilErasesValue),
            ("testDestroySession_removesSession",
                testDestroySession_removesSession)
        ]
    }

    // MARK: - Obtaining Values
    func testValueForKey_onNonExistantSession_isNil() {
        let subject = MemorySessionDriver(hash: MSDTHelper.application.hash)
        _ = Session(identifier: MSDTHelper.identifier, driver: subject)
        XCTAssertNil(subject.valueFor(key: "foo", identifier: MSDTHelper.identifier))
    }

    func testValueForKey_onExistingSession_onNonExistingKey_isNil() {
        let subject = MemorySessionDriver(hash: MSDTHelper.application.hash)
        _ = Session(identifier: MSDTHelper.identifier, driver: subject)
        subject.sessions = ["baz": [:]]
        XCTAssertNil(subject.valueFor(key: "foo", identifier: MSDTHelper.identifier))
    }

    func testValueForKey_onExistingSession_onExistingKey_isKeyValue() {
        let subject = MemorySessionDriver(hash: MSDTHelper.application.hash)
        _ = Session(identifier: MSDTHelper.identifier, driver: subject)
        subject.sessions = ["baz": ["foo":"bar"]]
        XCTAssertEqual(subject.valueFor(key: "foo", identifier: MSDTHelper.identifier), "bar")
    }

    // MARK: - Setting Values
    func testSetValueForKey_setsValueCorrectly() {
        let subject = MemorySessionDriver(hash: MSDTHelper.application.hash)
        let _ = Session(identifier: MSDTHelper.identifier, driver: subject)
        subject.set("foo", forKey: "bar", identifier: MSDTHelper.identifier)
        XCTAssertEqual(subject.sessions["baz"]?["bar"], "foo")
    }

    func testSetValueForKey_withExistingValue_overwritesValueCorrectly() {
        let subject = MemorySessionDriver(hash: MSDTHelper.application.hash)
        let _ = Session(identifier: MSDTHelper.identifier, driver: subject)
        subject.sessions = ["baz":["bar":"foo"]]
        subject.set("frob", forKey: "bar", identifier: MSDTHelper.identifier)
        XCTAssertEqual(subject.sessions["baz"]?["bar"], "frob")
    }

    func testSetValueForKey_withExistingValue_toNilErasesValue() {
        let subject = MemorySessionDriver(hash: MSDTHelper.application.hash)
        let _ = Session(identifier: MSDTHelper.identifier, driver: subject)
        subject.sessions = ["baz":["bar":"foo"]]
        subject.set(nil, forKey: "bar", identifier: MSDTHelper.identifier)
        XCTAssertNil(subject.sessions["baz"]?["bar"])
    }

    // MARK: - Destroying

    func testDestroySession_removesSession() {
        let subject = MemorySessionDriver(hash: MSDTHelper.application.hash)
        subject.sessions = ["baz":["bar":"foo"], "frob": [:]]
        let _ = Session(identifier: MSDTHelper.identifier, driver: subject)
        subject.destroy(MSDTHelper.identifier)

        guard subject.sessions["frob"] != nil else {
            XCTFail("Session was unexpectedly removed")
            return
        }

        XCTAssertEqual(subject.sessions["frob"]!, [String: String]())
    }
}
