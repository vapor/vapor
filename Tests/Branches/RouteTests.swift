//
//  RouteTests.swift
//  BranchRouter
//
//  Created by Logan Wright on 7/19/16.
//
//

import XCTest

import Engine
import Branches

public typealias HTTPRequestHandler = (HTTPRequest) throws -> HTTPResponseRepresentable


extension HTTPRequest: ParameterContainer {}

extension Router {
    public func route(_ request: HTTPRequest) -> Output? {
        return route(for: request,
                     host: request.uri.host,
                     method: request.method.description,
                     path: request.uri.path)
    }
}

class RouteTests: XCTestCase {
    func testRoute() throws {
        let router = Router<HTTPRequestHandler>()
        router.register(host: "0.0.0.0", method: HTTPMethod.get.description, path: "/hello") { req in
            return HTTPResponse(body: "HI")
        }

        let request = try HTTPRequest(method: .get, uri: "http://0.0.0.0/hello")
        let handler = router.route(request)
        XCTAssert(handler != nil)
        let response = try handler?(request).makeResponse(for: request)
        XCTAssert(response?.body.bytes?.string == "HI")
    }

    func testRouteParams() throws {
        let router = Router<HTTPRequestHandler>()
        router.register(host: "0.0.0.0", method: HTTPMethod.get.description, path: "/:zero/:one/:two/*") { req in
            let zero = req.parameters["zero"] ?? "[fail]"
            let one = req.parameters["one"] ?? "[fail]"
            let two = req.parameters["two"] ?? "[fail]"
            return HTTPResponse(body: "\(zero):\(one):\(two)")
        }

        let paths: [[String]] = [
            ["a", "b", "c"],
            ["1", "2", "3", "4"],
            ["x", "y", "z", "should", "be", "in", "wildcard"]
        ]
        try paths.forEach { path in
            let uri = URI(
                scheme: "http",
                userInfo: nil,
                host: "0.0.0.0",
                port: 80,
                path: path.joined(separator: "/"),
                query: nil,
                fragment: nil
            )
            let request = HTTPRequest(method: .get, uri: uri)
            let handler = router.route(request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse(for: request)
            XCTAssert(response?.body.bytes?.string == path.prefix(3).joined(separator: ":"))
        }
    }
}
