extension Router {
    // MARK: Lazy Middleware
    
    /// Creates a group with the provided `Middleware` type.
    ///
    ///     let group = router.grouped(DateMiddleware.self)
    ///     group.get("date") { ... }
    ///
    /// This middleware will be lazily initialized using the container upon the first request that invokes it.
    public func grouped<M>(_ middleware: M.Type) -> Router where M: Middleware {
        return LazyMiddlewareRouteGroup(M.self, cascadingTo: self)
    }

    /// Creates a group with the provided `Middleware` type.
    ///
    ///     router.group(DateMiddleware.self) { group in
    ///         group.get("date") { ... }
    ///     }
    ///
    /// This middleware will be lazily initialized using the container upon the first request that invokes it.
    public func group<M>(_ middleware: M.Type, configure: (Router) throws -> ()) rethrows where M: Middleware {
        try configure(LazyMiddlewareRouteGroup(M.self, cascadingTo: self))
    }
}

/// MARK: Private

/// Responder wrapper around middleware type. Lazily initializes the middleware upon request.
private struct LazyMiddlewareResponder<M>: Responder where M: Middleware {
    /// The responder to chain to.
    var responder: Responder

    /// Creates a new `LazyMiddlewareResponder`
    init(_ type: M.Type, chainingTo responder: Responder) {
        self.responder = responder
    }

    /// See `Responder`
    func respond(to req: Request) throws -> Future<Response> {
        return try req.make(M.self)
            .makeResponder(chainingTo: responder)
            .respond(to: req)
    }
}

/// Lazy initialized route group
private final class LazyMiddlewareRouteGroup<M>: Router where M: Middleware {
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
