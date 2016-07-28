//
//  BranchRouterTests.swift
//  BranchRouter
//
//  Created by Logan Wright on 7/19/16.
//
//

import XCTest
import Engine
import Branches

extension String: Swift.Error {}

class BranchRouterTests: XCTestCase {
    func testRouter() throws {
        let router = Router<HTTPRequestHandler>()
        router.register(host: "0.0.0.0", method: "GET", path: "/hello/") { request in
            return HTTPResponse(body: "Hello, World!")
        }

        let request = try HTTPRequest(method: .get, uri: "http://0.0.0.0/hello")
        let handler = router.route(request)
        XCTAssert(handler != nil)
        let response = try handler?(request).makeResponse(for: request)
        XCTAssert(response?.body.bytes?.string == "Hello, World!")
    }

    func testWildcardMethod() throws {
        let router = Router<HTTPRequestHandler>()
        router.register(host: "0.0.0.0", method: "*", path: "/hello/") { request in
            return HTTPResponse(body: "Hello, World!")
        }

        let method: [Engine.HTTPMethod] = [.get, .post, .put, .patch, .delete, .trace, .head, .options]
        try method.forEach { method in
            let request = try HTTPRequest(method: method, uri: "http://0.0.0.0/hello")
            let handler = router.route(request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse(for: request)
            XCTAssert(response?.body.bytes?.string == "Hello, World!")
        }
    }

    func testWildcardHost() throws {
        let router = Router<HTTPRequestHandler>()
        router.register(host: "*", method: "GET", path: "/hello/") { request in
            return HTTPResponse(body: "Hello, World!")
        }

        let hosts: [String] = ["0.0.0.0", "chat.app.com", "[255.255.255.255.255]", "slack.app.com"]
        try hosts.forEach { host in
            let request = try HTTPRequest(method: .get, uri: "http://\(host)/hello")
            let handler = router.route(request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse(for: request)
            XCTAssert(response?.body.bytes?.string == "Hello, World!")
        }
    }

    func testHostMatch() throws {
        let router = Router<HTTPRequestHandler>()

        let hosts: [String] = ["0.0.0.0", "chat.app.com", "[255.255.255.255.255]", "slack.app.com"]
        hosts.forEach { host in
            router.register(host: host, method: "GET", path: "/hello/") { request in
                return HTTPResponse(body: "Host: \(host)")
            }
        }

        try hosts.forEach { host in
            let request = try HTTPRequest(method: .get, uri: "http://\(host)/hello")
            let handler = router.route(request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse(for: request)
            XCTAssert(response?.body.bytes?.string == "Host: \(host)")
        }
    }

    func testMiss() throws {
        let router = Router<HTTPRequestHandler>()
        router.register(host: "0.0.0.0", method: "*", path: "/hello/") { request in
            XCTFail("should not be found, wrong host")
            return HTTPResponse(body: "[fail]")
        }

        let request = try HTTPRequest(method: .get, uri: "http://[255.255.255.255.255]/hello")
        let handler = router.route(request)
        XCTAssert(handler == nil)
    }

    func testWildcardPath() throws {
        let router = Router<HTTPRequestHandler>()
        router.register(host: "0.0.0.0", method: "GET", path: "/hello/*") { request in
            return HTTPResponse(body: "Hello, World!")
        }

        let paths: [String] = [
            "hello",
            "hello/zero",
            "hello/extended/path",
            "hello/very/extended/path.pdf"
        ]

        try paths.forEach { path in
            let request = try HTTPRequest(method: .get, uri: "http://0.0.0.0/\(path)")
            let handler = router.route(request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse(for: request)
            XCTAssert(response?.body.bytes?.string == "Hello, World!")
        }
    }

    func testParameters() throws {
        let router = Router<HTTPRequestHandler>()
        router.register(host: "0.0.0.0", method: "GET", path: "/hello/:name/:age") { request in
            guard let name = request.parameters["name"] else { throw "missing param: name" }
            guard let age = request.parameters["age"].flatMap({ Int($0) }) else { throw "missing or invalid param: age" }
            return HTTPResponse(body: "Hello, \(name) aged \(age).")
        }

        let namesAndAges: [(String, Int)] = [
            ("a", 12),
            ("b", 42),
            ("c", 200),
            ("d", 1)
        ]

        try namesAndAges.forEach { name, age in
            let request = try HTTPRequest(method: .get, uri: "http://0.0.0.0/hello/\(name)/\(age)")
            let handler = router.route(request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse(for: request)
            XCTAssert(response?.body.bytes?.string == "Hello, \(name) aged \(age).")
        }
    }

    func testEmpty() throws {
        let router = Router<HTTPRequestHandler>()
        router.register(host: "0.0.0.0", method: "GET", path: "/") { request in
            return HTTPResponse(body: "Hello, Empty!")
        }

        let empties: [String] = ["", "/"]
        try empties.forEach { emptypath in
            let uri = URI(scheme: "http", host: "0.0.0.0", path: emptypath)
            let request = HTTPRequest(method: .get, uri: uri)
            let handler = router.route(request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse(for: request)
            XCTAssert(response?.body.bytes?.string == "Hello, Empty!")
        }
    }

    func testNoHostWildcard() throws {
        let router = Router<HTTPRequestHandler>()
        router.register(host: "*", method: "GET", path: "/") { request in
            return HTTPResponse(body: "Hello, World!")
        }

        let uri = URI(
            scheme: "",
            host: ""
        )
        let request = HTTPRequest(method: .get, uri: uri)
        let handler = router.route(request)
        XCTAssert(handler != nil)
        let response = try handler?(request).makeResponse(for: request)
        XCTAssert(response?.body.bytes?.string == "Hello, World!")
    }
}
