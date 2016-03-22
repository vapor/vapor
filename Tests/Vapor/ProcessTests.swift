//
//  ProcessTests.swift
//  Vapor
//
//  Created by Logan Wright on 2/27/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor

#if os(Linux)
    extension ProcessTests: XCTestCaseProvider {
        var allTests : [(String, () throws -> Void)] {
            return [
                       ("testArgumentExtraction", testArgumentExtraction)
            ]
        }
    }
#endif

class ProcessTests: XCTestCase {

    func testArgumentExtraction() {
        let testArguments = ["--ip=123.45.1.6", "--port=8080", "--workDir=WorkDirectory"]

        let ip = Process.valueFor(argument: "ip", inArguments: testArguments)
        XCTAssert(ip == "123.45.1.6")

        let port = Process.valueFor(argument: "port", inArguments: testArguments)
        XCTAssert(port == "8080")

        let workDir = Process.valueFor(argument: "workDir", inArguments: testArguments)
        XCTAssert(workDir == "WorkDirectory")
    }
}
