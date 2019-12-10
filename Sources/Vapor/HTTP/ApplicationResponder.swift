extension Application {
    public var responder: Responder {
        ApplicationResponder(
            routes: self.routes,
            middleware: self.middleware.resolve()
        )
    }
}

/// Vapor's main `Responder` type. Combines configured middleware + router to create a responder.
internal struct ApplicationResponder: Responder {
    private let responder: Responder
    
    /// Creates a new `ApplicationResponder`.
    public init(routes: Routes, middleware: [Middleware] = []) {
        let router = RoutesResponder(routes: routes)
        self.responder = middleware.makeResponder(chainingTo: router)
    }

    /// See `Responder`.
    public func respond(to request: Request) -> EventLoopFuture<Response> {
        request.logger.info("\(request.method) \(request.url.path)")
        return self.responder.respond(to: request)
            .hop(to: request.eventLoop)
    }
}

// MARK: Private

/// Converts a `Router` into a `Responder`.
internal struct RoutesResponder: Responder {
    private let router: TrieRouter<Responder>

    /// Creates a new `RouterResponder`.
    init(routes: Routes) {
        let router = TrieRouter(Responder.self)
        for route in routes.all {
            // remove any empty path components
            let path = route.path.filter { component in
                switch component {
                case .constant(let string):
                    return string != ""
                default:
                    return true
                }
            }
            let route = RoutingKit.Route<Responder>(
                path: [.constant(route.method.string)] + path,
                output: route.responder
            )
            router.register(route: route)
        }
        self.router = router
    }

    /// See `Responder`.
    func respond(to request: Request) -> EventLoopFuture<Response> {
        guard let responder = self.route(request) else {
            return request.eventLoop.makeFailedFuture(Abort(.notFound))
        }
        return responder.respond(to: request)
    }
    
    /// See `Router`.
    private func route(_ request: Request) -> Responder? {
        let pathComponents = request.url.path
            .split(separator: "/")
            .map(String.init)
        
        let method = (request.method == .HEAD) ? .GET : request.method
        
        return self.router.route(
            path: [method.string] + pathComponents,
            parameters: &request.parameters
        )
    }
}
