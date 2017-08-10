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
import Service
import Configs

class FileMiddlewareTests: XCTestCase {
    func testETag() throws {
        let file = #file
        let fileMiddleware = FileMiddleware(publicDir: "")

        var config = Config()
        try config.set("droplet", "middleware", to: ["my-file"])
        var services = Services.default()
        services.register(fileMiddleware, name: "my-file", supports: [Middleware.self])
        
        let drop = try Droplet(config, services)
        
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
        
        var config = Config()
        try config.set("droplet", "middleware", to: ["error", "file"])
        
        let drop = try Droplet(config)
        
        let response = try drop.respond(to: Request(method: .get, path: file))
        XCTAssertEqual(response.status, .notFound, "Status code is not 404 for nonexisting file.")
    }

    func testThrowsOnRelativePath() throws {
        let file = "/../foo/bar/"
        
        var config = Config()
        try config.set("droplet", "middleware", to: ["error", "file"])
        
        let drop = try Droplet(config)

        let response = try drop.respond(to: Request(method: .get, path: file))
        XCTAssertEqual(response.status, HTTP.Status.forbidden)
    }
    
    static let allTests = [
        ("testETag", testETag),
        ("testNonExistingFile", testNonExistingFile),
        ("testThrowsOnRelativePath", testThrowsOnRelativePath)
    ]
}
