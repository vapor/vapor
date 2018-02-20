extension Router {
    /// Creates a group with the provided middleware type.
    ///
    /// This middleware will be lazily initialized using the container upon
    /// the first request that invokes it.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#middleware)
    public func grouped<M>(_ middleware: M.Type) -> Router where M: Middleware {
        return LazyMiddlewareRouteGroup(M.self, cascadingTo: self)
    }

    /// Creates a group with the provided middleware type.
    ///
    /// This middleware will be lazily initialized using the container upon
    /// the first request that invokes it.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#middleware)
    public func group<M>(_ middleware: M.Type, use: (Router) throws -> ()) rethrows where M: Middleware {
        try use(LazyMiddlewareRouteGroup(M.self, cascadingTo: self))
    }
}

/// Responder wrapper around middleware type.
/// Lazily initializes the middleware upon request.
fileprivate struct LazyMiddlewareResponder<M>: Responder where M: Middleware {
    /// The responder to chain to.
    var responder: Responder

    /// Creates a new `LazyMiddlewareResponder`
    init(_ type: M.Type, chainingTo responder: Responder) {
        self.responder = responder
    }

    /// See `Responder.respond(to:)`
    func respond(to req: Request) throws -> Future<Response> {
        return try req.make(M.self, for: Request.self)
            .makeResponder(chainedTo: responder)
            .respond(to: req)
    }
}

/// Lazy initialized route group
fileprivate final class LazyMiddlewareRouteGroup<M>: Router where M: Middleware {
    /// All routes registered to this group
    private(set) var routes: [Route<Responder>] = []

    /// The parent router.
    let `super`: Router

    /// Creates a new group
    init(_ type: M.Type, cascadingTo router: Router) {
        self.super = router
    }

    /// See `Router.register(route:)`
    func register(route: Route<Responder>) {
        self.routes.append(route)
        route.output = LazyMiddlewareResponder(M.self, chainingTo: route.output)
        self.super.register(route: route)
    }

    /// See `Router.route(request:)`
    func route(request: Request) -> Responder? {
        return self.super.route(request: request)
    }
}
