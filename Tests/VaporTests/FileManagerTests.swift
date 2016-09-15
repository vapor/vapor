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
        ("testReadsFromNonExistingFile", testReadsFromNonExistingFile),
        ("testFileExists", testFileExists),
        ("testFileDoesNotExist", testFileDoesNotExist),
        ("testDirectoryExists", testDirectoryExists),
        ("testDirectoryDoesNotExist", testDirectoryDoesNotExist)
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
        } catch DataFile.Error.fileLoad {
            // We're happy here
        }
    }
    
    func testFileExists() {
        let fileName = #file
        let existingFileResult = FileManager.fileAtPath(fileName)
        
        XCTAssertTrue(existingFileResult.exists, "exists is FALSE for existing file.")
        XCTAssertFalse(existingFileResult.isDirectory, "isDirectory is TRUE for a file.")
    }
    
    func testFileDoesNotExist() {
        let fileName = #file + "foo"
        let existingFileResult = FileManager.fileAtPath(fileName)
        
        XCTAssertFalse(existingFileResult.exists, "exists is TRUE for nonexisting file.")
        XCTAssertFalse(existingFileResult.isDirectory, "isDirectory is TRUE for nonexisting file.")
    }
    
    func testDirectoryExists() {
        let directory = "/"
        let attributes = FileManager.fileAtPath(directory)
        
        XCTAssertTrue(attributes.exists, "exists is FALSE for existing directory.")
        XCTAssertTrue(attributes.isDirectory, "isDirectory is FALSE for existing directory.")
    }
    
    func testDirectoryDoesNotExist() {
        let directory = "/nonsense/"
        let attributes = FileManager.fileAtPath(directory)
        
        XCTAssertFalse(attributes.exists, "exists is FALSE for nonexisting directory.")
        XCTAssertFalse(attributes.isDirectory, "exists is FALSE for nonexisting directory.")
    }
    
}
