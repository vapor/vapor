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
    func testDestroy_asksDriverToDestroy() {
        let subject = Session()
        let driver = TestDriver()
        subject.driver = driver
        subject.destroy()
        XCTAssertEqual(driver.actions.count, 1)
        guard !driver.actions.isEmpty else { return }
        guard case .Destroy(let session) = driver.actions[0] else {
            XCTFail("Recorded action was not a destroy action")
            return
        }

        XCTAssert(session === subject)
    }

    func testSubscriptGet_asksDriverForValue() {
        let subject = Session()
        let driver = TestDriver()
        subject.driver = driver
        _ = subject["test"]

        XCTAssertEqual(driver.actions.count, 1)
        guard !driver.actions.isEmpty else { return }
        guard case .ValueFor(let key, let session) = driver.actions[0] else {
            XCTFail("Recorded action was not a value for action")
            return
        }

        XCTAssertEqual(key, "test")
        XCTAssert(session === subject)
    }

    func testSubscriptSet_asksDriverToSetValue() {
        let subject = Session()
        let driver = TestDriver()
        subject.driver = driver
        subject["foo"] = "bar"

        XCTAssertEqual(driver.actions.count, 1)
        guard !driver.actions.isEmpty else { return }
        guard case .SetValue(let value, let key, let session) = driver.actions[0] else {
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
