//
//  RouteTests.swift
//  Vapor
//
//  Created by Matthew on 20/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest

class RouteTests: XCTestCase {
    
    func testSimpleResource() {
        
        Route.resource("foo", controller: Controller())
        
        let expectedRoutes = [
            "Get foo nil",
            "Post foo nil",
            "Get foo/:id nil",
            "Put foo/:id nil",
            "Delete foo/:id nil",
        ]
        
        assertRoutesExist(expectedRoutes)
       
    }
    
    private func assertRoutesExist(expected: [String]) {
        
        expected.forEach { description in
            let exists = Route.routes.filter { $0.description == description }.count == 1
            XCTAssert(exists, "routes should contain \(description)")
        }
    }
    
    func testNestedResource() {
        
        Route.resource("foo.bar", controller: Controller())
        
        let expectedRoutes = [
            "Get foo/:foo_id/bar nil",
            "Post foo/:foo_id/bar nil",
            "Get foo/:foo_id/bar/:id nil",
            "Put foo/:foo_id/bar/:id nil",
            "Delete foo/:foo_id/bar/:id nil",
            ]
        
        assertRoutesExist(expectedRoutes)
    }


}