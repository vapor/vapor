//
//  Application+Route.swift
//  Vapor
//
//  Created by Tanner Nelson on 2/23/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

extension Application {
    
    public final func get(path: String, handler: Route.Handler) {
        self.add(.Get, path: path, handler: handler)
    }
    
    public final func post(path: String, handler: Route.Handler) {
        self.add(.Post, path: path, handler: handler)
    }
    
    public final func put(path: String, handler: Route.Handler) {
        self.add(.Put, path: path, handler: handler)
    }
    
    public final func patch(path: String, handler: Route.Handler) {
        self.add(.Patch, path: path, handler: handler)
    }
    
    public final func delete(path: String, handler: Route.Handler) {
        self.add(.Delete, path: path, handler: handler)
    }
    
    public final func options(path: String, handler: Route.Handler) {
        self.add(.Options, path: path, handler: handler)
    }
    
    public final func any(path: String, handler: Route.Handler) {
        self.get(path, handler: handler)
        self.post(path, handler: handler)
        self.put(path, handler: handler)
        self.patch(path, handler: handler)
        self.delete(path, handler: handler)
    }
    

    
    /**
        Creates standard Create, Read, Update, Delete routes
        using the Handlers from a supplied `ResourcesController`.
     
        The `path` supports nested resources, like `users.photos`.
        users/:user_id/photos/:id
     
        Note: You are responsible for pluralizing your endpoints.
    */
    public final func resource(path: String, controller: ResourcesController) {

        let last = "/:id"
        
        let shortPath = path.componentsSeparatedByString(".")
            .flatMap { component in
                return [component, "/:\(component)_id/"]
            }
            .dropLast()
            .joinWithSeparator("")
        
        let fullPath = shortPath + last
        
        // ie: /users
        self.get(shortPath, handler: controller.index)
        self.post(shortPath, handler: controller.store)
        
        // ie: /users/:id
        self.get(fullPath, handler: controller.show)
        self.put(fullPath, handler: controller.update)
        self.delete(fullPath, handler: controller.destroy)
    }
    
    public final func add(method: Request.Method, path: String, handler: Route.Handler) {
        
        //Convert Route.Handler to Request.Handler
        var handler = { request in
            return try handler(request).response()
        }
        
        //Apply any scoped middlewares
        for middleware in Route.scopedMiddleware {
            handler = middleware.handle(handler)
        }
        
        //Store the route for registering with Router later
        let host = Route.scopedHost ?? "*"
        let route = Route(host: host, method: method, path: path, handler: handler)
        self.routes.append(route)
    }

    public final func add<ActionController: Controller>(method: Request.Method, path: String, action: (ActionController) -> () throws -> ResponseConvertible) {

        //Convert Action to Request.Handler
        var handler = { request in
            return try action(try ActionController(request: request))().response()
        }

        //Apply any scoped middlewares
        for middleware in Route.scopedMiddleware {
            handler = middleware.handle(handler)
        }

        //Store the route for registering with Router later
        let host = Route.scopedHost ?? "*"
        let route = Route(host: host, method: method, path: path, handler: handler)
        self.routes.append(route)
    }
    
    /**
        Applies the middleware to the routes defined
        inside the closure. This method can be nested within
        itself safely.
    */
    public final func middleware(middleware: Middleware.Type, handler: () -> ()) {
       self.middleware([middleware], handler: handler)
    }
    
    public final func middleware(middleware: [Middleware.Type], handler: () -> ()) {
        let original = Route.scopedMiddleware
        Route.scopedMiddleware += middleware
        
        handler()
        
        Route.scopedMiddleware = original
    }
    
    public final func host(host: String, handler: () -> Void) {
        Route.scopedHost = host
        
        handler()
        
        Route.scopedHost = nil
    }
}