/// Vapor's main `Responder` type. Combines configured middleware + router to create a responder.
public struct ApplicationResponder: Responder {
    private let responder: Responder
    
    /// Creates a new `ApplicationResponder`.
    public init(routes: Routes, middleware: [Middleware] = []) {
        let router = HTTPRoutesResponder(routes: routes)
        self.responder = middleware.makeResponder(chainingTo: router)
    }

    /// See `Responder`.
    public func respond(to request: Request) -> EventLoopFuture<HTTPResponse> {
        return self.responder.respond(to: request)
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
    public func respond(to request: Request) -> EventLoopFuture<HTTPResponse> {
        guard let responder = self.route(request) else {
            return self.eventLoop.makeFailedFuture(Abort(.notFound))
        }
        return responder.respond(to: request)
    }
    
    /// See `Router`.
    private func route(_ request: Request) -> Responder? {
        let path: [String] = request.http.urlString
            .split(separator: "?", maxSplits: 1)[0]
            .split(separator: "/")
            .map { String($0) }
        return self.router.route(path: [request.http.method.string] + path, parameters: &request.parameters)
    }
}
