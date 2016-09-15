//
//  FileMiddlewareTests.swift
//  Vapor
//
//  Created by Sergo Beruashvili on 15/09/16.
//
//

import XCTest
import HTTP
import Vapor

class FileMiddlewareTests: XCTestCase {
    static let allTests = [
        ("testETag", testETag),
        ("testNonExistingFile", testNonExistingFile)
    ]
    
    func testETag() {
        
        let file = #file
        let fileMiddleWare = FileMiddleware(publicDir: "/")
        let drop = Droplet(availableMiddleware: ["file": fileMiddleWare])
        
        var headers: [HeaderKey: String] = [:]
        
        // First make sure it returns data with 200
        do {
            let response = try drop.respond(to: Request(method: .get, path: file))
            XCTAssertTrue(response.status == .ok, "Status code is not OK ( 200 ) for existing file.")
            XCTAssertTrue(response.body.bytes!.count > 0, "File content body IS NOT provided for existing file.")
            
            if let ETag = response.headers["ETag"] {
                headers["If-None-Match"] = ETag
            } else {
                XCTFail("File MiddleWare not return ETag header")
            }
        } catch {
            XCTFail("Droplet did break on existing file request.")
        }
        
        // Now check that returns 304
        do {
            let request = Request(method: .get, path: file)
            request.headers = headers
            
            let response = try drop.respond(to: request)
            XCTAssertTrue(response.status == .notModified, "Status code is not 304 for existing cached file.")
            XCTAssertTrue(response.body.bytes!.count == 0, "File content body IS provided for existing file.")
            
            // Make sure ETag did not change
            XCTAssertTrue(headers["If-None-Match"] == response.headers["ETag"], "Generated ETag for cached file does not match old one.")
        } catch {
            XCTFail("Droplet did break on existing file request.")
        }
    }
    
    
    func testNonExistingFile() {
        let file = "/nonsense/file.notexists"
        let fileMiddleWare = FileMiddleware(publicDir: "/")
        let drop = Droplet(availableMiddleware: ["file": fileMiddleWare])
        
        do {
            let response = try drop.respond(to: Request(method: .get, path: file))
            XCTAssertTrue(response.status == .notFound, "Status code is not 404 for nonexisting file.")
        } catch {
            XCTFail("Droplet did break on existing file request.")
        }
    }
}
