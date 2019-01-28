/// Vapor's main `Responder` type. Combines configured middleware + router to create a responder.
public struct ApplicationResponder: Responder {
    private let responder: Responder
    
    /// Creates a new `ApplicationResponder`.
    public init(
        routes: Routes,
        middleware: [Middleware] = []
    ) {
        let router = HTTPRoutesResponder(routes: routes)
        self.responder = middleware.makeResponder(chainingTo: router)
    }

    /// See `Responder`.
    public func respond(to req: RequestContext) -> EventLoopFuture<HTTPResponse> {
        return self.responder.respond(to: req)
    }
}

// MARK: Private

/// Converts a `Router` into a `Responder`.
public struct HTTPRoutesResponder: Responder {
    private let router: TrieRouter<Responder>
    private let eventLoop: EventLoop

    /// Creates a new `RouterResponder`.
    public init(routes: Routes) {
        let router = TrieRouter(Responder.self)
        for route in routes.routes {
            let route = RoutingKit.Route<Responder>(
                path: [.constant(route.method.string)] + route.path,
                output: route.responder
            )
            router.register(route: route)
        }
        self.router = router
        self.eventLoop = routes.eventLoop
    }

    /// See `Responder`.
    public func respond(to req: RequestContext) -> EventLoopFuture<HTTPResponse> {
        guard let responder = self.route(request: req) else {
            return self.eventLoop.makeFailedFuture(Abort(.notFound))
        }
        return responder.respond(to: req)
    }
    
    /// See `Router`.
    private func route(request: RequestContext) -> Responder? {
        #warning("TODO: allow router to accept substring")
        let path: [String] = request.http.urlString
            .split(separator: "?", maxSplits: 1)[0]
            .split(separator: "/")
            .map { String($0) }
        return self.router.route(path: [request.http.method.string] + path, parameters: &request._parameters)
    }
}
