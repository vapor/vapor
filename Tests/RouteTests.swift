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

    class DummyController: Controller {}
    
    let controller = DummyController()
    let router = NodeRouter()

    func testSinglePath() {
        
        let path = "foo"
        
        let url = "http://tanner.xyz"
        
        let redirect = Redirect(to: url)
        XCTAssert(redirect.redirectLocation == url, "redirect location should be url")
        
        
        var found = false
        for (key, val) in redirect.headers {
            if key == "Location" && val == url {
                found = true
            }
        }
        XCTAssert(found, "Location header should be in headers")
    }

    
}