//
//  SessionTests.swift
//  Vapor
//
//  Created by James Richard on 3/7/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

@testable import Vapor
import XCTest

class SessionTests: XCTestCase {
    static var allTests : [(String, SessionTests -> () throws -> Void)] {
        return [
           ("testDestroy_asksDriverToDestroy", testDestroy_asksDriverToDestroy),
           ("testSubscriptGet_asksDriverForValue", testSubscriptGet_asksDriverForValue),
           ("testSubscriptSet_asksDriverToSetValue", testSubscriptSet_asksDriverToSetValue)
        ]
    }
    
    func testDestroy_asksDriverToDestroy() {
        let driver = TestDriver()
        let subject = Session(identifier: "baz", driver: driver)
        subject.destroy()
        guard let action = driver.actions.first, case .Destroy(let session) = action else {
            XCTFail("No actions recorded or recorded action was not a destroy action")
            return
        }

        XCTAssert(session === subject)
    }

    func testSubscriptGet_asksDriverForValue() {
        let driver = TestDriver()
        let subject = Session(identifier: "baz", driver: driver)
        _ = subject["test"]

        guard let action = driver.actions.first, case .ValueFor(let key, let session) = action else {
            XCTFail("No actions recorded or recorded action was not a value for action")
            return
        }

        XCTAssertEqual(key, "test")
        XCTAssert(session === subject)
    }

    func testSubscriptSet_asksDriverToSetValue() {
        let driver = TestDriver()
        let subject = Session(identifier: "baz", driver: driver)
        subject["foo"] = "bar"

        guard let action = driver.actions.first, case .SetValue(let value, let key, let session) = action else {
            XCTFail("No actions recorded or recorded action was not a set value action")
            return
        }

        XCTAssertEqual(value, "bar")
        XCTAssertEqual(key, "foo")
        XCTAssert(session === subject)
    }
}

private class TestDriver: SessionDriver {
    var app = Application()
    
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
