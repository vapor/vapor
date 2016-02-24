//
//  Application+Route.swift
//  Vapor
//
//  Created by Tanner Nelson on 2/23/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

extension Application {
    
    public class Route: CustomStringConvertible {
        static var scopedHost: String?
        static var scopedMiddleware: [Middleware.Type] = []
       
        
        let method: Request.Method
        let path: String
        let handler: Request.Handler
        var hostname: String?
        
        public typealias Handler = Request throws -> ResponseConvertible
        
        init(method: Request.Method, path: String, handler: Request.Handler) {
            self.method = method
            self.path = path
            self.handler = handler
        }
        
        public var description: String {
            return "\(self.method) \(self.path) \(self.hostname)"
        }
        
    }
    
    public final func get(path: String, closure: Route.Handler) {
        self.add(.Get, path: path, closure: closure)
    }
    
    public final func post(path: String, closure: Route.Handler) {
        self.add(.Post, path: path, closure: closure)
    }
    
    public final func put(path: String, closure: Route.Handler) {
        self.add(.Put, path: path, closure: closure)
    }
    
    public final func patch(path: String, closure: Route.Handler) {
        self.add(.Patch, path: path, closure: closure)
    }
    
    public final func delete(path: String, closure: Route.Handler) {
        self.add(.Delete, path: path, closure: closure)
    }
    
    public final func options(path: String, closure: Route.Handler) {
        self.add(.Options, path: path, closure: closure)
    }
    
    public final func any(path: String, closure: Route.Handler) {
        self.get(path, closure: closure)
        self.post(path, closure: closure)
        self.put(path, closure: closure)
        self.patch(path, closure: closure)
        self.delete(path, closure: closure)
    }
    
    public final func resource(path: String, controller: Controller) {

        let last = "/:id"
        
        let shortPath = path.componentsSeparatedByString(".")
            .flatMap { component in
                return [component, "/:\(component)_id/"]
            }
            .dropLast()
            .joinWithSeparator("")
        
        let fullPath = shortPath + last
        
        // ie: /users
        self.get(shortPath, closure: controller.index)
        self.post(shortPath, closure: controller.store)
        
        // ie: /users/:id
        self.get(fullPath, closure: controller.show)
        self.put(fullPath, closure: controller.update)
        self.delete(fullPath, closure: controller.destroy)
    }
    
    public final func add(method: Request.Method, path: String, closure: Route.Handler) {
        
        //Convert Route.Handler to Request.Handler
        var handler = { request in
            return try closure(request).response()
        }
        
        //Apply any scoped middlewares
        for middleware in Route.scopedMiddleware {
            handler = middleware.handle(handler)
        }
        
        //Store the route for registering with Router later
        let route = Route(method: method, path: path, handler: handler)
        
        //Add scoped hostname if we have one
        if let hostname = Route.scopedHost {
            route.hostname = hostname
        }
        
        self.routes.append(route)
    }
    
    public final func host(host: String, closure: () -> Void) {
        Route.scopedHost = host
        closure()
        Route.scopedHost = nil
    }
}