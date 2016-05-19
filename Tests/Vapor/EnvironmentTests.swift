//
//  EnvironmentTests.swift
//  Vapor
//
//  Created by Shaun Harrison on 2/26/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor

class EnvironmentTests: XCTestCase {
    static var allTests: [(String, EnvironmentTests -> () throws -> Void)] {
        return [
           ("testEnvironment", testEnvironment),
           ("testDetectEnvironmentHandler", testDetectEnvironmentHandler),
           ("testInEnvironment", testInEnvironment)
        ]
    }

    func testEnvironment() {
        let app = Application()
        XCTAssert(app.config.environment == .Development, "Incorrect environment: \(app.config.environment)")
    }

    func testDetectEnvironmentHandler() {
        let app = Application()
        app.config = Config(environment: .Custom("xctest"))
        XCTAssert(app.config.environment == .Custom("xctest"), "Incorrect environment: \(app.config.environment)")
    }

    func testInEnvironment() {
        let app = Application()
        app.config = Config(environment: .Custom("xctest"))
        XCTAssert(app.inEnvironment(.Production, .Development, .Custom("xctest")), "Environment not correctly detected: \(app.config.environment)")
    }

}
