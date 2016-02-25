//
//  ResourcesControllerTests.swift
//  Vapor
//
//  Created by Matthew on 20/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest

class ResourcesControllerTests: XCTestCase {
    
    class TestController: ResourcesController {
        
        var lock: (
            index: Int,
            store: Int,
            show: Int,
            update: Int,
            destroy: Int
        ) = (0, 0, 0, 0, 0)
        
        /// Display many instances
        func index(request: Request) throws -> ResponseConvertible {
            self.lock.index += 1
            return "index"
        }
        
        /// Create a new instance.
        func store(request: Request) throws -> ResponseConvertible {
            self.lock.store += 1
            return "store"
        }
        
        /// Show an instance.
        func show(request: Request) throws -> ResponseConvertible {
            self.lock.show += 1
            return "show"
        }
        
        /// Update an instance.
        func update(request: Request) throws -> ResponseConvertible {
            self.lock.update += 1
            return "update"
        }
        
        /// Delete an instance.
        func destroy(request: Request) throws -> ResponseConvertible {
            self.lock.destroy += 1
            return "destroy"
        }
        
    }
    
    func testController() {
        
        let app = Application()
        
        let controller = TestController()
        app.resource("foo", controller: controller)
        
        app.bootRoutes()
        
        let fooIndex = Request(method: .Get, path: "foo", address: nil, headers: [:], body: [])
        if let handler = app.router.route(fooIndex) {
            do {
                try handler(request: fooIndex)
                XCTAssert(controller.lock.index == 1, "foo.index Lock not correct")
            } catch {
                XCTFail("foo.index handler failed")
            }
        } else {
            XCTFail("No handler found for foo.index")
        }
        
    }
    
}
