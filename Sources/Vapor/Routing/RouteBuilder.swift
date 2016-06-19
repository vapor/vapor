public protocol RouteBuilder {
    var leadingPath: String { get }
    var scopedMiddleware: [HTTP.Middleware] { get }

    func add(
        middleware: [HTTP.Middleware],
        method: HTTP.Method,
        path: String,
        handler: Route.Handler
    )
}

extension RouteBuilder {
    public func add(
        _ method: HTTP.Method,
        path: String,
        handler: Route.Handler
    ) {
        add(middleware: [], method: method, path: path, handler: handler)
    }
}

extension RouteBuilder {
    public var leadingPath: String { return "" }
    public var scopedMiddleware: [HTTP.Middleware] { return [] }
}

extension RouteBuilder {
    public func grouped(_ path: String) -> Route.Link {
        return Route.Link(
            parent: self,
            leadingPath: path,
            scopedMiddleware: scopedMiddleware
        )
    }

    public func grouped(_ path: String, _ body: @noescape (group: Route.Link) -> Void) {
        let group = grouped(path)
        body(group: group)
    }

    public func grouped(_ middlewares: HTTP.Middleware...) -> Route.Link {
        return Route.Link(
            parent: self,
            leadingPath: nil,
            scopedMiddleware: scopedMiddleware + middlewares
        )
    }

    public func grouped(_ middlewares: [HTTP.Middleware]) -> Route.Link {
        return Route.Link(
            parent: self,
            leadingPath: nil,
            scopedMiddleware: scopedMiddleware + middlewares
        )
    }

    public func grouped(_ middlewares: HTTP.Middleware..., _ body: @noescape (group: Route.Link) -> Void) {
        let groupObject = grouped(middlewares)
        body(group: groupObject)
    }

    public func grouped(middleware middlewares: [HTTP.Middleware], _ body: @noescape (group: Route.Link) -> Void) {
        let groupObject = grouped(middlewares)
        body(group: groupObject)
    }
}

//public struct CombineMiddleware: Middleware {
//    let combination: (respondTo: HTTP.Request, chainingTo: Responder) throws -> HTTP.Response
//
//    init(_ left: Middleware, _ right: Middleware) {
//        combination = { request, responder in
//            left.respond(to: request, chainingTo: right)
//        }
//    }
//    public func respond(to request: HTTP.Request, chainingTo next: Responder) throws -> HTTP.Response {
//        let response = combination(request)
////        next.respond(to: 
////            { request in
////                return try self.respond(to: request, chainingTo: responder)
////            }
////    }
//}

extension Application: RouteBuilder {
    /**
        Adds a route handler for an HTTP request using a given HTTP verb at a given
        path. The provided handler will be ran whenever the path is requested with
        the given method.
        
        - parameter middleware: scoped middleware to apply to this specific handler
        - parameter method: The `Request.Method` that the handler should be executed for.
        - parameter path: The HTTP path that handler can run at.
        - parameter handler: The code to process the request with.
    */
    public func add(
        middleware: [Middleware],
        method: HTTP.Method,
        path: String,
        handler: Route.Handler
    ) {
        // Convert Route.Handler to Request.Handler
        let wrapped: HTTPResponder = HTTP.Request.Handler { request in
            return try handler(request).makeResponse()
        }
        let responder = middleware.chain(to: wrapped)
        let route = Route(host: "*", method: method, path: path, responder: responder)

        routes.append(route)
        router.register(route)
    }
}

extension HTTPMiddleware {
    func chain(to responder: HTTPResponder) -> HTTPResponder {
        return HTTP.Request.Handler { request in
            return try self.respond(to: request, chainingTo: responder)
        }
    }
}

extension Collection where Iterator.Element == Middleware {
    func chain(to responder: HTTPResponder) -> HTTPResponder {
        return reversed().reduce(responder) { nextResponder, nextMiddleware in
            return HTTP.Request.Handler { request in
                return try nextMiddleware.respond(to: request, chainingTo: nextResponder)
            }
        }
    }
}
