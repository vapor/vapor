//
//  RouteTests.swift
//  Vapor
//
//  Created by Matthew on 20/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor

class ControllerTests: XCTestCase {
    
    static var allTests : [(String, ControllerTests -> () throws -> Void)] {
        return [
            ("testController", testController)
        ]
    }

    class TestController: ResourceController, DefaultInitializable {
        required init() {
            
        }
        
        static var lock: (
            index: Int,
            store: Int,
            show: Int,
            update: Int,
            destroy: Int
        ) = (0, 0, 0, 0, 0)
        
        /// Display many instances
        func index(request: Request) throws -> ResponseConvertible {
            TestController.lock.index += 1
            return "index"
        }
        
        /// Create a new instance.
        func store(request: Request) throws -> ResponseConvertible {
            TestController.lock.store += 1
            return "store"
        }
        
        /// Show an instance.
        func show(request: Request) throws -> ResponseConvertible {
            TestController.lock.show += 1
            return "show"
        }
        
        /// Update an instance.
        func update(request: Request) throws -> ResponseConvertible {
            TestController.lock.update += 1
            return "update"
        }
        
        /// Delete an instance.
        func destroy(request: Request) throws -> ResponseConvertible {
            TestController.lock.destroy += 1
            return "destroy"
        }
        
    }
    
    func testController() {
        
        let app = Application()
        
        app.resource("foo", controller: TestController.self)
        
        app.bootRoutes()
        
        let fooIndex = Request(method: .Get, path: "foo", address: nil, headers: [:], body: [])
        if let handler = app.router.route(fooIndex) {
            do {
                try handler(request: fooIndex)
                XCTAssert(TestController.lock.index == 1, "foo.index Lock not correct")
            } catch {
                XCTFail("foo.index handler failed")
            }
        } else {
            XCTFail("No handler found for foo.index")
        }
        
    }
    
}
