//
//  RouteTests.swift
//  Vapor
//
//  Created by Matthew on 20/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor

#if os(Linux)
    extension RouteTests: XCTestCaseProvider {
        var allTests : [(String, () throws -> Void)] {
            return [
                ("testRoute", testRoute)
            ]
        }
    }
#endif

class RouteTests: XCTestCase {
 
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
        
        var fooFound = false
        var barFound = false
        var bazFound = false
        
        for route in app.routes {
            if route.path == "foo" && route.method == .Get && route.hostname == "*" {
                fooFound = true
            }
            
            if route.path == "bar" && route.method == .Post && route.hostname == "*" {
                barFound = true
            }
            
            if route.path == "baz" && route.method == .Put && route.hostname == "google.com" {
                bazFound = true
            }
        }
        
        if !fooFound {
            XCTFail("GET /foo was not found")
        }
        
        if !barFound {
            XCTFail("POST /bar was not found")
        }
        
        if !bazFound {
            XCTFail("PUT google.com/baz was not found")
        }
    }

}