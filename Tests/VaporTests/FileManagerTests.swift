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
        ("testReadsFromNonExistingFile", testReadsFromNonExistingFile)
    ]
    
    func testReadsFromExistingFile() {
        let filename = #file
        let bytes = try! FileManager.readBytesFromFile(filename)
        XCTAssertFalse(bytes.isEmpty)
    }
    
    func testReadsFromNonExistingFile() throws {
        let filename = "/nonsene/doesntExist.txt"
        do {
            let _ = try FileManager.readBytesFromFile(filename)
            XCTFail("Should never reach here")
        } catch DataFile.Error.load {
            // We're happy here
        }
    }
}
