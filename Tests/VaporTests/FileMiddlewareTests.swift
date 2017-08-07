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
    
    func testETag() throws {
        let file = #file
        let fileMiddleWare = FileMiddleware(publicDir: "")
        let drop = try Droplet(middleware: [fileMiddleWare])
        
        var headers: [HeaderKey: String] = [:]
        
        // First make sure it returns data with 200
        let response = try drop.respond(to: Request(method: .get, path: file))
        XCTAssertEqual(response.status, .ok, "Status code is not OK ( 200 ) for existing file.")
        guard case .chunked = response.body else {
            XCTFail("Not chunked response")
            return
        }

        if let ETag = response.headers["ETag"] {
            headers["If-None-Match"] = ETag
        } else {
            XCTFail("File MiddleWare not return ETag header")
        }

        // Now check that returns 304
        let request304 = Request(method: .get, path: file)
        request304.headers = headers

        let response304 = try drop.respond(to: request304)
        XCTAssertTrue(response304.status == .notModified, "Status code is not 304 for existing cached file.")
        XCTAssertTrue(response304.body.bytes!.count == 0, "File content body IS provided for existing file.")

        // Make sure ETag did not change
        XCTAssertTrue(headers["If-None-Match"] == response304.headers["ETag"], "Generated ETag for cached file does not match old one.")
    }

    func testNonExistingFile() throws {
        let file = "/nonsense/file.notexists"
        let drop = try Droplet()
        
        let response = try drop.respond(to: Request(method: .get, path: file))
        XCTAssertEqual(response.status, .notFound, "Status code is not 404 for nonexisting file.")
    }

    func testCorrectMessageForNotFoundFromOriginalResponse() throws {
        let path = "/existing_path"
        let drop = try Droplet()
        drop.get(path) { _ in
            throw Abort(.notFound, reason: "Some important message")
        }

        let response = try drop.respond(to: Request(method: .get, path: path))

        guard let json = response.json else {
            XCTFail("response is not json")
            return
        }

        XCTAssertEqual(try json.get("reason") as String, "Some important message")
    }

    func testThrowsOnRelativePath() throws {
        let file = "/../foo/bar/"
        let drop = try Droplet()

        let response = try drop.respond(to: Request(method: .get, path: file))
        XCTAssertEqual(response.status, HTTP.Status.forbidden)
    }
}
