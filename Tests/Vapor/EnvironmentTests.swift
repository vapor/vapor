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
        XCTAssert(app.environment == .Development, "Incorrect environment: \(app.environment)")
    }

    func testDetectEnvironmentHandler() {
        let app = Application()
        app.detectEnvironmentHandler = { _ in
            return .Custom("xctest")
        }

        XCTAssert(app.environment == .Custom("xctest"), "Incorrect environment: \(app.environment)")
    }

    func testInEnvironment() {
        let app = Application()
        app.detectEnvironmentHandler = { _ in
            return .Custom("xctest")
        }

        XCTAssert(app.inEnvironment(.Production, .QA, .Custom("xctest")), "Environment not correctly detected: \(app.environment)")
    }

}
