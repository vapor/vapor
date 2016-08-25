import XCTest
@testable import Vapor

/**
    Working around linux testing bug
*/
private class MSDTHelper {
    static var droplet = Droplet()
    static var identifier = "baz"
}

class MemorySessionDriverTests: XCTestCase {
    static let allTests = [
        ("testValueForKey_onNonExistantSession_isNil", testValueForKey_onNonExistantSession_isNil),
        ("testValueForKey_onExistingSession_onNonExistingKey_isNil", testValueForKey_onExistingSession_onNonExistingKey_isNil),
        ("testValueForKey_onExistingSession_onExistingKey_isKeyValue", testValueForKey_onExistingSession_onExistingKey_isKeyValue),
        ("testSetValueForKey_setsValueCorrectly", testSetValueForKey_setsValueCorrectly),
        ("testSetValueForKey_withExistingValue_overwritesValueCorrectly", testSetValueForKey_withExistingValue_overwritesValueCorrectly),
        ("testSetValueForKey_withExistingValue_toNilErasesValue", testSetValueForKey_withExistingValue_toNilErasesValue),
        ("testDestroySession_removesSession", testDestroySession_removesSession)
    ]

    // MARK: - Obtaining Values
    func testValueForKey_onNonExistantSession_isNil() {
        let subject = MemorySessions(hash: MSDTHelper.droplet.hash)
        _ = Session(identifier: MSDTHelper.identifier, sessions: subject)
        XCTAssertNil(subject.value(for: "foo", identifier: MSDTHelper.identifier))
    }

    func testValueForKey_onExistingSession_onNonExistingKey_isNil() {
        let subject = MemorySessions(hash: MSDTHelper.droplet.hash)
        _ = Session(identifier: MSDTHelper.identifier, sessions: subject)
        subject.sessions = ["baz": [:]]
        XCTAssertNil(subject.value(for: "foo", identifier: MSDTHelper.identifier))
    }

    func testValueForKey_onExistingSession_onExistingKey_isKeyValue() {
        let subject = MemorySessions(hash: MSDTHelper.droplet.hash)
        _ = Session(identifier: MSDTHelper.identifier, sessions: subject)
        subject.sessions = ["baz": ["foo":"bar"]]
        XCTAssertEqual(subject.value(for: "foo", identifier: MSDTHelper.identifier), "bar")
    }

    // MARK: - Setting Values
    func testSetValueForKey_setsValueCorrectly() {
        let subject = MemorySessions(hash: MSDTHelper.droplet.hash)
        let _ = Session(identifier: MSDTHelper.identifier, sessions: subject)
        subject.set("foo", for: "bar", identifier: MSDTHelper.identifier)
        XCTAssertEqual(subject.sessions["baz"]?["bar"], "foo")
    }

    func testSetValueForKey_withExistingValue_overwritesValueCorrectly() {
        let subject = MemorySessions(hash: MSDTHelper.droplet.hash)
        let _ = Session(identifier: MSDTHelper.identifier, sessions: subject)
        subject.sessions = ["baz":["bar":"foo"]]
        subject.set("frob", for: "bar", identifier: MSDTHelper.identifier)
        XCTAssertEqual(subject.sessions["baz"]?["bar"], "frob")
    }

    func testSetValueForKey_withExistingValue_toNilErasesValue() {
        let subject = MemorySessions(hash: MSDTHelper.droplet.hash)
        let _ = Session(identifier: MSDTHelper.identifier, sessions: subject)
        subject.sessions = ["baz":["bar":"foo"]]
        subject.set(nil, for: "bar", identifier: MSDTHelper.identifier)
        XCTAssertNil(subject.sessions["baz"]?["bar"])
    }

    // MARK: - Destroying

    func testDestroySession_removesSession() {
        let subject = MemorySessions(hash: MSDTHelper.droplet.hash)
        subject.sessions = ["baz":["bar":"foo"], "frob": [:]]
        let _ = Session(identifier: MSDTHelper.identifier, sessions: subject)
        subject.destroy(MSDTHelper.identifier)

        guard subject.sessions["frob"] != nil else {
            XCTFail("Session was unexpectedly removed")
            return
        }

        XCTAssertEqual(subject.sessions["frob"]!, [String: String]())
    }
}
