//
//  EnvironmentTests.swift
//  Vapor
//
//  Created by Shaun Harrison on 2/26/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor

#if os(Linux)
    extension EnvironmentTests: XCTestCaseProvider {
        var allTests : [(String, () throws -> Void)] {
            return [
                ("testEnvironment", testEnvironment),
                ("testDetectEnvironmentHandler", testDetectEnvironmentHandler),
                ("testInEnvironment", testInEnvironment)
            ]
        }
    }
#endif

class EnvironmentTests: XCTestCase {

    func testEnvironment() {
        let app = Application()
        XCTAssert(app.environment == "local", "Incorrect environment: \(app.environment)")
    }

    func testDetectEnvironmentHandler() {
        let app = Application()
        app.detectEnvironmentHandler = { _ in
            return "xctest"
        }

        XCTAssert(app.environment == "xctest", "Incorrect environment: \(app.environment)")
    }

    func testInEnvironment() {
        let app = Application()
        app.detectEnvironmentHandler = { _ in
            return "xctest"
        }

        XCTAssert(app.inEnvironment("production", "qa", "xctest"), "Environment not correctly detected: \(app.environment)")
    }

}
