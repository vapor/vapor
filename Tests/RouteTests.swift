//
//  RouteTests.swift
//  Vapor
//
//  Created by Matthew on 20/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest

class RouteTests: XCTestCase {
    
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
        
        let app = Application()
        app.resource("foo", controller: controller)
        
        self.executeTemplates(app, templates: templates, assertController: controller)
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
        
        let app = Application()
        app.resource("foo.bar", controller: controller)
        
        self.executeTemplates(app, templates: templates, assertController: controller)
    }
    
    private func executeTemplates(app: Application, templates: [ResourceTestTemplate], assertController: ResourceTestController) {
        app.bootRoutes()
        
        do {
            try templates.forEach { template in
                let request = template.request()
                
                if let handler = app.router.route(request) {
                    try handler(request: request)
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
    
    init() {
        locks = [
            "index" : 0,
            "store" : 0,
            "show" : 0,
            "update" : 0,
            "destroy" : 0
        ]
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
    
    func index(request: Request) throws -> ResponseConvertible {
        incrementLock("index")
        return "index"
    }
    
    ///Create a new instance.
    func store(request: Request) throws -> ResponseConvertible {
        incrementLock("store")
        return "store"
    }
    
    ///Show an instance.
    func show(request: Request) throws -> ResponseConvertible {
        print(request.parameters)
        XCTAssert(request.parameters["id"] != nil, "Did not receive id parameter")
        incrementLock("show")
        return "show"
    }
    
    ///Update an instance.
    func update(request: Request) throws -> ResponseConvertible {
        XCTAssert(request.parameters["id"] != nil, "Did not receive id parameter")
        incrementLock("update")
        return "update"
    }
    
    ///Delete an instance.
    func destroy(request: Request) throws -> ResponseConvertible {
        XCTAssert(request.parameters["id"] != nil, "Did not receive id parameter")
        incrementLock("destroy")
        return "destory"
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
        XCTAssert(request.parameters[nestedResourceIdKey] != nil, "Did not receive nested id parameter")
        return try super.show(request)
    }
    
    ///Update an instance.
    override func update(request: Request) throws -> ResponseConvertible {
        XCTAssert(request.parameters[nestedResourceIdKey] != nil, "Did not receive nested id parameter")
        return try super.update(request)
    }
    
    ///Delete an instance.
    override func destroy(request: Request) throws -> ResponseConvertible {
        XCTAssert(request.parameters[nestedResourceIdKey] != nil, "Did not receive nested id parameter")
        return try super.destroy(request)
    }
}
