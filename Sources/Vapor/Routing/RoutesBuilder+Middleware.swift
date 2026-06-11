extension RoutesBuilder {
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
    public func grouped(_ middleware: any Middleware...) -> any RoutesBuilder {
        self.grouped(middleware)
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
    public func group(_ middleware: any Middleware..., configure: (any RoutesBuilder) throws -> ()) rethrows {
        try self.group(middleware, configure: configure)
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
    public func grouped(_ middleware: [any Middleware]) -> any RoutesBuilder {
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
    public func group(_ middleware: [any Middleware], configure: (any RoutesBuilder) throws -> ()) rethrows {
        try configure(MiddlewareGroup(root: self, middleware: middleware))
    }
}

// MARK: Private

/// Middleware grouping route.
private final class MiddlewareGroup: RoutesBuilder {
    /// Router to cascade to.
    let root: any RoutesBuilder

    /// Additional middleware.
    let middleware: [any Middleware]

    /// Creates a new ``MiddlewareGroup``.
    init(root: any RoutesBuilder, middleware: [any Middleware]) {
        self.root = root
        self.middleware = middleware
    }
    
    // See `RoutesBuilder.add(_:)`.
    func add(_ route: Route) {
        route.responder = self.middleware.makeResponder(chainingTo: route.responder)
        self.root.add(route)
    }
}
