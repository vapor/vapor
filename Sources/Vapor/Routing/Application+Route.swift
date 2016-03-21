//
//  Application+Route.swift
//  Vapor
//
//  Created by Tanner Nelson on 2/23/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

public protocol StringInitializable {
    init?(from string: String) throws
}

extension Int: StringInitializable {
    public init?(from string: String) throws {
        guard let int = Int(string) else {
            return nil
        }
        
        self = int
    }
}
extension String: StringInitializable {
    public init?(from string: String) throws {
        self = string
    }
}

extension Application {
    
    public final func any(path: String, handler: Route.Handler) {
        self.get(path, handler: handler)
        self.post(path, handler: handler)
        self.put(path, handler: handler)
        self.patch(path, handler: handler)
        self.delete(path, handler: handler)
    }
    
    /**
        Creates standard Create, Read, Update, Delete routes
        using the Handlers from a supplied `ResourceController`.
     
        The `path` supports nested resources, like `users.photos`.
        users/:user_id/photos/:id
     
        Note: You are responsible for pluralizing your endpoints.
    */
    public final func resource<ResourceControllerType: ResourceController>(path: String, makeControllerWith controllerFactory: () -> ResourceControllerType) {
        let last = "/:id"

        //FIXME
        #if swift(>=3.0)
            let shortPath = path.componentsSeparatedByString(".")
                .flatMap { component in
                    return [component, "/:\(component)_id/"]
                }
                .dropLast()
                .joinWithSeparator("")
        #else
            let shortPath = ""
        #endif
        
        let fullPath = shortPath + last

        // ie: /users
        self.add(.Get, path: shortPath, makeControllerWith: controllerFactory, action: ResourceControllerType.index)
        self.add(.Post, path: shortPath, makeControllerWith: controllerFactory, action: ResourceControllerType.store)

        // ie: /users/:id
        self.add(.Get, path: fullPath, makeControllerWith: controllerFactory, action: ResourceControllerType.show)
        self.add(.Put, path: fullPath, makeControllerWith: controllerFactory, action: ResourceControllerType.update)
        self.add(.Delete, path: fullPath, makeControllerWith: controllerFactory, action: ResourceControllerType.destroy)
    }

    public final func resource<ResourceControllerType: ResourceController where ResourceControllerType: DefaultInitializable>(path: String, controller: ResourceControllerType.Type) {
        resource(path, makeControllerWith: ResourceControllerType.init)
    }

    public final func add<Controller>(method: Request.Method, path: String, makeControllerWith controllerFactory: () -> Controller, action: Controller -> Route.Handler) {
        add(method, path: path) { request in
            let controller = controllerFactory()
            let actionCall = action(controller)
            return try actionCall(request).response()
        }
    }

    public final func add<Controller: DefaultInitializable>(method: Request.Method, path: String, action: Controller -> Route.Handler) {
        add(method, path: path, makeControllerWith: Controller.init, action: action)
    }
    
    public final func add<Controller: ApplicationInitializable>(method: Request.Method, path: String, action: Controller -> Route.Handler) {
        add(method, path: path, makeControllerWith: {
            return Controller(application: self)
        }, action: action)
    }
    
    public final func add(method: Request.Method, path: String, handler: Route.Handler) {
        
        //Convert Route.Handler to Request.Handler
        var handler = { request in
            return try handler(request).response()
        }
        
        //Apply any scoped middlewares
        for middleware in scopedMiddleware {
            handler = middleware.handle(handler, for: self)
        }
        
        //Store the route for registering with Router later
        let host = scopedHost ?? "*"
        
        //Apply any scoped prefix
        var path = path
        if let prefix = scopedPrefix {
            path = prefix + "/" + path
        }
        
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
        let original = scopedMiddleware
        scopedMiddleware += middleware
        
        handler()
        
        scopedMiddleware = original
    }
    
    public final func host(host: String, handler: () -> Void) {
        let original = scopedHost
        scopedHost = host
        
        handler()
        
        scopedHost = original
    }
    
    /**
        Create multiple routes with the same base URL
        without repeating yourself.
    */
    public func group(prefix: String, @noescape handler: () -> Void) {
        let original = scopedPrefix
        
        //append original with a trailing slash
        if let original = original {
            scopedPrefix = original + "/" + prefix
        } else {
            scopedPrefix = prefix
        }
        
        handler()
        
        scopedPrefix = original
    }
}