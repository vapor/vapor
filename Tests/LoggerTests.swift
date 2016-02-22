//
//  LoggerTests.swift
//  Vapor
//
//  Created by Matthew on 23/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor

class ConsoleLoggerTests: XCTestCase {

    func testVerboseDidLogToConsole() {
        Log.info("foo")
        //XCTAssert(true)
    }

}
