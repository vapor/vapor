/**
    Any type that conforms to this protocol
    can be passed as a requirement to Vapor's
    type-safe route calls.
*/
public protocol StringInitializable {
    init?(from string: String) throws
}

///Allow the Int type to be a type-safe routing parameter
extension Int: StringInitializable {
    public init?(from string: String) throws {
        guard let int = Int(string) else {
            return nil
        }

        self = int
    }
}

///Allow the String type to be a type-safe routing parameter
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

        Note: You are responsible for pluralizing your endpoints.
    */
    public final func resource<Resource: ResourceController>(_ path: String, makeControllerWith controllerFactory: () -> Resource) {
        //GET /entities
        self.get(path) { request in
            return try controllerFactory().index(request)
        }

        //POST /entities
        self.post(path) { request in
            return try controllerFactory().index(request)
        }

        //GET /entities/:id
        self.get(path, Resource.Item.self) { request, item in
            return try controllerFactory().show(request, item: item)
        }

        //PUT /entities/:id
        self.put(path, Resource.Item.self) { request, item in
            return try controllerFactory().update(request, item: item)
        }

        //DELETE /intities/:id
        self.delete(path, Resource.Item.self) { request, item in
            return try controllerFactory().destroy(request, item: item)
        }

    }

    public final func resource<Resource: ResourceController where Resource: ApplicationInitializable>(_ path: String, controller: Resource.Type) {
        resource(path) {
            return controller.init(application: self)
        }
    }

    public final func resource<Resource: ResourceController where Resource: DefaultInitializable>(_ path: String, controller: Resource.Type) {
        resource(path) {
            return controller.init()
        }
    }

    public final func add(_ method: Request.Method, path: String, handler: Route.Handler) {
        //Convert Route.Handler to Request.Handler
        var responder: Responder = Request.Handler { request in
            return try handler(request).makeResponse()
        }

        //Apply any scoped middlewares
        for middleware in self.scopedMiddleware {
            responder = middleware.chain(to: responder)
        }

        //Store the route for registering with Router later
        let host = scopedHost ?? "*"

        //Apply any scoped prefix
        var path = path
        if let prefix = scopedPrefix {
            path = prefix + "/" + path
        }

        let route = Route(host: host, method: method, path: path, responder: responder)
        self.routes.append(route)
    }

    /**
        Applies the middleware to the routes defined
        inside the closure. This method can be nested within
        itself safely.
    */
    public final func middleware(_ middleware: Middleware, handler: () -> ()) {
       self.middleware([middleware], handler: handler)
    }

    public final func middleware(_ middleware: [Middleware], handler: () -> ()) {
        let original = scopedMiddleware
        scopedMiddleware += middleware

        handler()

        scopedMiddleware = original
    }

    public final func host(_ host: String, handler: () -> Void) {
        let original = scopedHost
        scopedHost = host

        handler()

        scopedHost = original
    }

    /**
        Create multiple routes with the same base URL
        without repeating yourself.
    */
    public func group(_ prefix: String, @noescape handler: () -> Void) {
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
