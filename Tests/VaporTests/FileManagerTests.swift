//
//  FileManagerTests.swift
//  Vapor
//
//  Created by Jim Kubicek on 6/12/16.
//
//

import XCTest
import Core
@testable import Vapor

class FileManagerTests: XCTestCase {
    static let allTests = [
        ("testReadsFromExistingFile", testReadsFromExistingFile),
    ]
    
    func testReadsFromExistingFile() {
        let filename = #file
        let bytes = FileManager.default.contents(atPath: filename)?.makeBytes() ?? []
        XCTAssertFalse(bytes.isEmpty)
    }
}
