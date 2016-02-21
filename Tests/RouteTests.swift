//
//  RouteTests.swift
//  Vapor
//
//  Created by Matthew on 20/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest

class RouteTests: XCTestCase {
    private let Route = Router()
    
    private struct ResourceTestTemplate {
        let method: Request.Method
        let path: String
        
        func request() -> Request {
            return  Request(method: method,
                            path: path,
                            address: nil,
                            headers: [:],
                            body: [])
        }
    }
    
    func testSimpleResource() {
        let templates = [
            ResourceTestTemplate(method: .Get, path: "foo"),
            ResourceTestTemplate(method: .Post, path: "foo"),
            ResourceTestTemplate(method: .Get, path: "foo/test-foo-id"),
            ResourceTestTemplate(method: .Put, path: "foo/test-foo-id"),
            ResourceTestTemplate(method: .Delete, path: "foo/test-foo-id")
        ]

        let controller = ResourceTestController()
        Route.resource("foo", controller: controller)
        
        executeTemplates(templates, assertController: controller)
    }
    
    func testNestedResource() {
        let templates = [
            ResourceTestTemplate(method: .Get, path: "foo/test-foo-id/bar"),
            ResourceTestTemplate(method: .Post, path: "foo/test-foo-id/bar"),
            ResourceTestTemplate(method: .Get, path: "foo/test-foo-id/bar/test-bar-id"),
            ResourceTestTemplate(method: .Put, path: "foo/test-foo-id/bar/test-bar-id"),
            ResourceTestTemplate(method: .Delete, path: "foo/test-foo-id/bar/test-bar-id")
        ]
        
        let controller = NestedResourceTestController(nestedResourceIdKey: "foo_id")
        Route.resource("foo.bar", controller: controller)
        
        executeTemplates(templates, assertController: controller)
    }
    
    private func executeTemplates(templates: [ResourceTestTemplate], assertController: ResourceTestController) {
        do {
            try templates.forEach { template in
                let request = template.request()
                if let handler = Route.handle(request) {
                    try handler(request)
                } else {
                    XCTFail("Unable to find resource handler for request: \(request)")
                }
            }
        } catch {
            XCTFail("Resource handler unexpectedly threw")
        }
        
        assertController.assertAllLocksAreOne()
    }

}

private class ResourceTestController: Controller {
    
    var locks: [String : Int]
    
    // MARK: Init
    
    override init() {
        locks = [
            "index" : 0,
            "store" : 0,
            "show" : 0,
            "update" : 0,
            "destroy" : 0
        ]
        super.init()
    }
    
    // MARK:
    
    private func incrementLock(lock: String) {
        locks[lock] = locks[lock]?.successor()
    }
    
    private func assertAllLocksAreOne() {
        locks.forEach { key, val in
            XCTAssert(val == 1, "\(key) function did not run, or ran too many times: \(val)")
        }
    }
    
    // MARK: Handlers
    
    override func index(request: Request) throws -> ResponseConvertible {
        incrementLock("index")
        return try super.index(request)
    }
    
    ///Create a new instance.
    override func store(request: Request) throws -> ResponseConvertible {
        incrementLock("store")
        return try super.store(request)
    }
    
    ///Show an instance.
    override func show(request: Request) throws -> ResponseConvertible {
        XCTAssert(request.parameters["id"] != nil)
        incrementLock("show")
        return try super.show(request)
    }
    
    ///Update an instance.
    override func update(request: Request) throws -> ResponseConvertible {
        XCTAssert(request.parameters["id"] != nil)
        incrementLock("update")
        return try super.update(request)
    }
    
    ///Delete an instance.
    override func destroy(request: Request) throws -> ResponseConvertible {
        XCTAssert(request.parameters["id"] != nil)
        incrementLock("destroy")
        return try super.destroy(request)
    }
}

private class NestedResourceTestController: ResourceTestController {
    let nestedResourceIdKey: String
    
    init(nestedResourceIdKey: String) {
        self.nestedResourceIdKey = nestedResourceIdKey
        super.init()
    }
    
    // MARK: Handlers
    
    override func index(request: Request) throws -> ResponseConvertible {
        return try super.index(request)
    }
    
    ///Create a new instance.
    override func store(request: Request) throws -> ResponseConvertible {
        return try super.store(request)
    }
    
    ///Show an instance.
    override func show(request: Request) throws -> ResponseConvertible {
        XCTAssert(request.parameters[nestedResourceIdKey] != nil)
        return try super.show(request)
    }
    
    ///Update an instance.
    override func update(request: Request) throws -> ResponseConvertible {
        XCTAssert(request.parameters[nestedResourceIdKey] != nil)
        return try super.update(request)
    }
    
    ///Delete an instance.
    override func destroy(request: Request) throws -> ResponseConvertible {
        XCTAssert(request.parameters[nestedResourceIdKey] != nil)
        return try super.destroy(request)
    }
}
