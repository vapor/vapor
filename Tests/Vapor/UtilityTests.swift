//
//  UtilityTests.swift
//  Vapor
//
//  Created by Robert Thompson on 03/02/2016
//

import XCTest
import Foundation
import libc
@testable import Vapor

#if os(Linux)
    extension UtilityTests: XCTestCaseProvider {
        var allTests : [(String, () throws -> Void)] {
            return [
                ("testNSDataSequenceType", testNSDataSequenceType),
            ]
        }
    }
#endif

class UtilityTests: XCTestCase {
    func testNSDataSequenceType() {
        let string = "Hello world!"
        let bytes = string.withCString {
            (str: UnsafePointer<CChar>) -> UnsafeMutablePointer<UInt8> in
            let result = UnsafeMutablePointer<UInt8>.alloc(string.utf8.count + 1)
            memcpy(result, str, string.utf8.count)
            return result
        }

        defer { free(bytes) }

        let data = NSData(bytes: bytes, length: string.utf8.count + 1)
        var i = 0
        for byte in data {
            XCTAssert(byte == bytes[i])
            i += 1
        }
    }
}
