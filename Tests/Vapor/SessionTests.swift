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
    static var allTests: [(String, (SessionTests) -> () throws -> Void)] {
        return [
           ("testDestroy_asksDriverToDestroy", testDestroy_asksDriverToDestroy),
           ("testSubscriptGet_asksDriverForValue", testSubscriptGet_asksDriverForValue),
           ("testSubscriptSet_asksDriverToSetValue", testSubscriptSet_asksDriverToSetValue),
           ("testIdentifierCreation", testIdentifierCreation)
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

    func testIdentifierCreation() {
        let app = Application()

        app.get("cookie") { request in
            request.session?["hi"] = "test"
            return "hi"
        }

        app.bootRoutes()

        var request = Request(method: .get, path: "cookie")
        request.headers["Cookie"] = "vapor-session=123"

        guard let response = try? app.respond(to: request) else {
            XCTFail("Could not get response")
            return
        }

        var sessionMiddleware: SessionMiddleware?

        for middleware in app.globalMiddleware {
            if let middleware = middleware as? SessionMiddleware {
                sessionMiddleware = middleware
            }
        }

        XCTAssert(sessionMiddleware != nil, "Could not find session middleware")

        XCTAssert(sessionMiddleware?.driver.contains(identifier: "123") == false, "Session should not contain 123")

        XCTAssert(response.cookies["vapor-session"] != nil, "No cookie was added")

        let id = response.cookies["vapor-session"] ?? ""
        XCTAssert(sessionMiddleware?.driver.contains(identifier: id) == true, "Session did not contain cookie")
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

    private func contains(identifier: String) -> Bool {
        return false
    }

    func set(_ value: String?, forKey key: String, identifier: String) {
        actions.append(.SetValue(value: value, key: key, identifier: identifier))
    }

    func destroy(_ identifier: String) {
        actions.append(.Destroy(identifier: identifier))
    }

}
