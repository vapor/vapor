//
//  SessionTests.swift
//  Vapor
//
//  Created by James Richard on 3/7/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

@testable import Vapor
import XCTest

#if os(Linux)
    extension SessionTests: XCTestCaseProvider {
        var allTests : [(String, () throws -> Void)] {
            return [
                       ("testDestroy_asksDriverToDestroy", testDestroy_asksDriverToDestroy),
                       ("testSubscriptGet_asksDriverForValue", testSubscriptGet_asksDriverForValue),
                       ("testSubscriptSet_asksDriverToSetValue", testSubscriptSet_asksDriverToSetValue)
            ]
        }
    }
#endif

class SessionTests: XCTestCase {
    var originalDriver: SessionDriver!
    private var testDriver: TestDriver!

    // TODO: When XCTestCase is converted from a protocol to a class on Linux, these should be renamed to setUp() and 
    // tearDown(), and not called manually.
    func doSetUp() {
        originalDriver = Session.driver
        testDriver = TestDriver()
        Session.driver = testDriver
    }
    
    func doTearDown() {
        Session.driver = originalDriver
        testDriver = nil
    }
    
    func testDestroy_asksDriverToDestroy() {
        doSetUp()
        defer { doTearDown() }
        let subject = Session()
        subject.destroy()
        XCTAssertEqual(testDriver.actions.count, 1)
        guard !testDriver.actions.isEmpty else { return }
        guard case .Destroy(let session) = testDriver.actions[0] else {
            XCTFail("Recorded action was not a destroy action")
            return
        }

        XCTAssert(session === subject)
    }

    func testSubscriptGet_asksDriverForValue() {
        doSetUp()
        defer { doTearDown() }
        let subject = Session()
        _ = subject["test"]

        XCTAssertEqual(testDriver.actions.count, 1)
        guard !testDriver.actions.isEmpty else { return }
        guard case .ValueFor(let key, let session) = testDriver.actions[0] else {
            XCTFail("Recorded action was not a value for action")
            return
        }

        XCTAssertEqual(key, "test")
        XCTAssert(session === subject)
    }

    func testSubscriptSet_asksDriverToSetValue() {
        doSetUp()
        defer { doTearDown() }
        let subject = Session()
        subject["foo"] = "bar"

        XCTAssertEqual(testDriver.actions.count, 1)
        guard !testDriver.actions.isEmpty else { return }
        guard case .SetValue(let value, let key, let session) = testDriver.actions[0] else {
            XCTFail("Recorded action was not a set value action")
            return
        }

        XCTAssertEqual(value, "bar")
        XCTAssertEqual(key, "foo")
        XCTAssert(session === subject)
    }
}

private class TestDriver: SessionDriver {
    enum Action {
        case ValueFor(key: String, session: Session)
        case SetValue(value: String?, key: String, session: Session)
        case Destroy(session: Session)
    }

    var actions = [Action]()

    func makeSessionIdentifier() -> String {
        return "Foo"
    }

    func valueFor(key key: String, inSession session: Session) -> String? {
        actions.append(.ValueFor(key: key, session: session))
        return nil
    }

    func set(value: String?, forKey key: String, inSession session: Session) {
        actions.append(.SetValue(value: value, key: key, session: session))
    }

    func destroy(session: Session) {
        actions.append(.Destroy(session: session))
    }

}