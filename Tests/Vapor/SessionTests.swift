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
    static var allTests: [(String, SessionTests -> () throws -> Void)] {
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
        guard let action = driver.actions.first, case .Destroy = action else {
            XCTFail("No actions recorded or recorded action was not a destroy action")
            return
        }
    }

    func testSubscriptGet_asksDriverForValue() {
        let driver = TestDriver()
        let subject = Session(identifier: "baz", driver: driver)
        _ = subject["test"]

        guard let action = driver.actions.first, case .ValueFor(let key) = action else {
            XCTFail("No actions recorded or recorded action was not a value for action")
            return
        }

        XCTAssertEqual(key.key, "test")
    }

    func testSubscriptSet_asksDriverToSetValue() {
        let driver = TestDriver()
        let subject = Session(identifier: "baz", driver: driver)
        subject["foo"] = "bar"

        guard let action = driver.actions.first, case .SetValue(let key) = action else {
            XCTFail("No actions recorded or recorded action was not a set value action")
            return
        }

        XCTAssertEqual(key.value, "bar")
        XCTAssertEqual(key.key, "foo")
    }
}

private class TestDriver: SessionDriver {
    var app = Application()

    enum Action {
        case ValueFor(key: String, identifier: String)
        case SetValue(value: String?, key: String, identifier: String)
        case Destroy(identifier: String)
    }

    var actions = [Action]()

    func makeSessionIdentifier() -> String {
        return "Foo"
    }

    func valueFor(key: String, identifier: String) -> String? {
        actions.append(.ValueFor(key: key, identifier: identifier))
        return nil
    }

    func set(_ value: String?, forKey key: String, identifier: String) {
        actions.append(.SetValue(value: value, key: key, identifier: identifier))
    }

    func destroy(_ identifier: String) {
        actions.append(.Destroy(identifier: identifier))
    }

}
