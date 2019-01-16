extension Router {
    // MARK: Middleware

    /// Creates a new `Router` wrapped in the supplied variadic `Middleware`.
    ///
    ///     let group = router.grouped(FooMiddleware(), BarMiddleware())
    ///     // all routes added will be wrapped by Foo & Bar middleware
    ///     group.get(...) { ... }
    ///
    /// - parameters:
    ///     - middleware: Variadic `Middleware` to wrap `Router` in.
    /// - returns: New `Router` wrapped in `Middleware`.
    public func grouped(_ middleware: HTTPMiddleware...) -> Router {
        return grouped(middleware)
    }

    /// Creates a new `Router` wrapped in the supplied variadic `Middleware`.
    ///
    ///     router.group(FooMiddleware(), BarMiddleware()) { group in
    ///         // all routes added will be wrapped by Foo & Bar middleware
    ///         group.get(...) { ... }
    ///     }
    ///
    /// - parameters:
    ///     - middleware: Variadic `Middleware` to wrap `Router` in.
    ///     - configure: Closure to configure the newly created `Router`.
    public func group(_ middleware: HTTPMiddleware..., configure: (Router) -> ()) {
        return group(middleware, configure: configure)
    }

    /// Creates a new `Router` wrapped in the supplied array of `Middleware`.
    ///
    ///     let group = router.grouped([FooMiddleware(), BarMiddleware()])
    ///     // all routes added will be wrapped by Foo & Bar middleware
    ///     group.get(...) { ... }
    ///
    /// - parameters:
    ///     - middleware: Array of `[Middleware]` to wrap `Router` in.
    /// - returns: New `Router` wrapped in `Middleware`.
    public func grouped(_ middleware: [HTTPMiddleware]) -> Router {
        guard middleware.count > 0 else {
            return self
        }
        return MiddlewareGroup(root: self, middleware: middleware)
    }

    /// Creates a new `Router` wrapped in the supplied array of `Middleware`.
    ///
    ///     router.group([FooMiddleware(), BarMiddleware()]) { group in
    ///         // all routes added will be wrapped by Foo & Bar middleware
    ///         group.get(...) { ... }
    ///     }
    ///
    /// - parameters:
    ///     - middleware: Array of `[Middleware]` to wrap `Router` in.
    ///     - configure: Closure to configure the newly created `Router`.
    public func group(_ middleware: [HTTPMiddleware], configure: (Router) -> ()) {
        configure(MiddlewareGroup(root: self, middleware: middleware))
    }
}

// MARK: Private

/// Middleware grouping route.
private final class MiddlewareGroup: Router {
    var eventLoop: EventLoop {
        return self.root.eventLoop
    }
    
    /// See `Router`.
    var routes: [Route<HTTPResponder>] {
        return root.routes
    }

    /// Router to cascade to.
    let root: Router

    /// Additional middleware.
    let middleware: [HTTPMiddleware]

    /// Creates a new `MiddlewareGroup`.
    init(root router: Router, middleware: [HTTPMiddleware]) {
        self.root = router
        self.middleware = middleware
    }

    /// See `Router`.
    func register(route: Route<HTTPResponder>) {
        // chain the output to this middleware
        route.output = middleware.makeResponder(chainingTo: route.output)
        // then register
        root.register(route: route)
    }

    /// See `Router`.
    func route(request: HTTPRequestContext) -> HTTPResponder? {
        return root.route(request: request)
    }
}
