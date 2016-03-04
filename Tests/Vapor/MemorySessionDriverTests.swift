//
//  MemorySessionDriverTests.swift
//  Vapor
//
//  Created by James Richard on 3/4/16.
//

import XCTest
@testable import Vapor

#if os(Linux)
    extension MemorySessionDriverTests: XCTestCaseProvider {
        var allTests : [(String, () throws -> Void)] {
            return [
                       ("testValueForKey_onSessionThatDoesntHaveIdentifier_isNil", testValueForKey_onSessionThatDoesntHaveIdentifier_isNil),
                       ("testValueForKey_onSessionWithIdentifier_onNonExistantSession_isNil", testValueForKey_onSessionWithIdentifier_onNonExistantSession_isNil),
                       ("testValueForKey_onSessionWithIdentifier_onExistingSession_onNonExistingKey_isNil", testValueForKey_onSessionWithIdentifier_onExistingSession_onNonExistingKey_isNil),
                       ("testValueForKey_onSessionWithIdentifier_onExistingSession_onExistingKey_isKeyValue", testValueForKey_onSessionWithIdentifier_onExistingSession_onExistingKey_isKeyValue),
                       ("testSetValueForKey_onSessionThatDoesntHaveIdentifier_doesntAlterSessions", testSetValueForKey_onSessionThatDoesntHaveIdentifier_doesntAlterSessions),
                       ("testSetValueForKey_onSessionWithIdentifier_setsValueCorrectly", testSetValueForKey_onSessionWithIdentifier_setsValueCorrectly),
                       ("testSetValueForKey_onSessionWithIdentifier_withExistingValue_overwritesValueCorrectly", testSetValueForKey_onSessionWithIdentifier_withExistingValue_overwritesValueCorrectly),
                       ("testSetValueForKey_onSessionWithIdentifier_withExistingValue_toNilErasesValue", testSetValueForKey_onSessionWithIdentifier_withExistingValue_toNilErasesValue),
                       ("testDestroySession_onSessionThatDoesntHaveIdentifier_doesntAlterSessions", testDestroySession_onSessionThatDoesntHaveIdentifier_doesntAlterSessions),
                       ("testDestroySession_onSessionThatHasIdentifier_removesSession", testDestroySession_onSessionThatHasIdentifier_removesSession)
            ]
        }
    }
#endif

class MemorySessionDriverTests: XCTestCase {
    // MARK: - Obtaining Values
    func testValueForKey_onSessionThatDoesntHaveIdentifier_isNil() {
        let subject = MemorySessionDriver()
        let session = Session()
        XCTAssertNil(subject.valueFor(key: "foo", inSession: session))
    }

    func testValueForKey_onSessionWithIdentifier_onNonExistantSession_isNil() {
        let subject = MemorySessionDriver()
        let session = Session()
        session.identifier = "baz"
        XCTAssertNil(subject.valueFor(key: "foo", inSession: session))
    }

    func testValueForKey_onSessionWithIdentifier_onExistingSession_onNonExistingKey_isNil() {
        let subject = MemorySessionDriver()
        let session = Session()
        session.identifier = "baz"
        subject.sessions = ["baz": [:]]
        XCTAssertNil(subject.valueFor(key: "foo", inSession: session))
    }

    func testValueForKey_onSessionWithIdentifier_onExistingSession_onExistingKey_isKeyValue() {
        let subject = MemorySessionDriver()
        let session = Session()
        session.identifier = "baz"
        subject.sessions = ["baz": ["foo":"bar"]]
        XCTAssertEqual(subject.valueFor(key: "foo", inSession: session), "bar")
    }

    // MARK: - Setting Values
    func testSetValueForKey_onSessionThatDoesntHaveIdentifier_doesntAlterSessions() {
        let subject = MemorySessionDriver()
        let session = Session()
        subject.set("foo", forKey: "bar", inSession: session)
        XCTAssertTrue(subject.sessions.isEmpty)
    }

    func testSetValueForKey_onSessionWithIdentifier_setsValueCorrectly() {
        let subject = MemorySessionDriver()
        let session = Session()
        session.identifier = "baz"
        subject.set("foo", forKey: "bar", inSession: session)
        XCTAssertEqual(subject.sessions["baz"]?["bar"], "foo")
    }

    func testSetValueForKey_onSessionWithIdentifier_withExistingValue_overwritesValueCorrectly() {
        let subject = MemorySessionDriver()
        let session = Session()
        session.identifier = "baz"
        subject.sessions = ["baz":["bar":"foo"]]
        subject.set("frob", forKey: "bar", inSession: session)
        XCTAssertEqual(subject.sessions["baz"]?["bar"], "frob")
    }

    func testSetValueForKey_onSessionWithIdentifier_withExistingValue_toNilErasesValue() {
        let subject = MemorySessionDriver()
        let session = Session()
        session.identifier = "baz"
        subject.sessions = ["baz":["bar":"foo"]]
        subject.set(nil, forKey: "bar", inSession: session)
        XCTAssertNil(subject.sessions["baz"]?["bar"])
    }

    // MARK: - Destroying

    func testDestroySession_onSessionThatDoesntHaveIdentifier_doesntAlterSessions() {
        let subject = MemorySessionDriver()
        let session = Session()
        let sessions = ["baz":["bar":"foo"]]
        subject.sessions = sessions
        subject.destroy(session)

        guard subject.sessions["baz"] != nil else {
            XCTFail("Session was unexpectedly removed")
            return
        }

        XCTAssertEqual(subject.sessions["baz"]!, ["bar":"foo"])
    }

    func testDestroySession_onSessionThatHasIdentifier_removesSession() {
        let subject = MemorySessionDriver()
        subject.sessions = ["baz":["bar":"foo"], "frob": [:]]
        let session = Session()
        session.identifier = "baz"
        subject.destroy(session)

        guard subject.sessions["frob"] != nil else {
            XCTFail("Session was unexpectedly removed")
            return
        }

        XCTAssertEqual(subject.sessions["frob"]!, [String: String]())
    }
}
