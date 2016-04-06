//
//  RouteTests.swift
//  Vapor
//
//  Created by Matthew on 20/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor

class RouteTests: XCTestCase {

    static var allTests: [(String, RouteTests -> () throws -> Void)] {
        return [
           ("testNestedRouteScopedPrefixPopsCorrectly", testNestedRouteScopedPrefixPopsCorrectly),
           ("testRoute", testRoute),
           ("testRouteScopedPrefix", testRouteScopedPrefix)
        ]
    }

    func testRoute() {

        let app = Application()

        app.get("foo") { request in
            return ""
        }

        app.post("bar") { request in
            return ""
        }

        app.host("google.com") {
            app.put("baz") { request in
                return ""
            }
        }

        self.assertRouteExists("foo", method: .get, host: "*", inRoutes: app.routes)
        self.assertRouteExists("bar", method: .post, host: "*", inRoutes: app.routes)
        self.assertRouteExists("baz", method: .put, host: "google.com", inRoutes: app.routes)
    }


    func testRouteScopedPrefix() {
        let app = Application()

        app.group("group/path") {
            app.get("1") { request in
                return ""
            }

            app.options("2") { request in
                return ""
            }
        }

        self.assertRouteExists("group/path/1", method: .get, host: "*", inRoutes: app.routes)
        self.assertRouteExists("group/path/2", method: .options, host: "*", inRoutes: app.routes)
    }

    func testNestedRouteScopedPrefixPopsCorrectly() {
        let app = Application()

        app.group("group") {
            app.group("subgroup") {
                app.get("1") { request in
                    return ""
                }
            }

            app.options("2") { request in
                return ""
            }
        }

        self.assertRouteExists("group/subgroup/1", method: .get, host: "*", inRoutes: app.routes)
        self.assertRouteExists("group/2", method: .options, host: "*", inRoutes: app.routes)
    }

    func testRouteAbort() {
        let app = Application()

        app.get("400") { request in
            print("from 400")
            throw Abort.badRequest
        }

        app.bootRoutes()


        print(app.routes)

        let request = Request(method: .get, uri: URI(path: "400"), headers: [:], body: [])
        guard var handler = app.router.route(request)?.handler else {
            XCTFail("No handler found")
            return
        }

        do {
            let response = try handler.respond(request)
            print(response)
            var body = response.body
            let data = try body.becomeBuffer()
            let string = try String(data: data)
            print(string)

            XCTFail("Handler did not throw error")
        } catch Abort.badRequest {
            //pass
        } catch {
            XCTFail("Handler threw incorrect error")
        }

        handler = AbortMiddleware().intercept(handler)

        do {
            let request = try handler.respond(request)
            XCTAssert(request.status.statusCode == 400, "Incorrect response status")
        } catch {
            XCTFail("Middleware did not handle abort")
        }
    }


    func assertRouteExists(path: String, method: Request.Method, host: String, inRoutes routes: [Route]) {
        var found = false

        for route in routes {
            if route.path == path && route.method == method && route.hostname == host {
                found = true
            }

        }

        if !found {
            XCTFail("\(method) \(path) was not found")
        }
    }
}
