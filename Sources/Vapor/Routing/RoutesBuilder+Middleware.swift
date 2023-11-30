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
    public func grouped(_ middleware: AsyncMiddleware...) -> RoutesBuilder {
        return self.grouped(middleware)
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
    public func group(_ middleware: AsyncMiddleware..., configure: (RoutesBuilder) throws -> ()) rethrows {
        return try self.group(middleware, configure: configure)
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
    public func grouped(_ middleware: [AsyncMiddleware]) -> RoutesBuilder {
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
    public func group(_ middleware: [AsyncMiddleware], configure: (RoutesBuilder) throws -> ()) rethrows {
        try configure(MiddlewareGroup(root: self, middleware: middleware))
    }
}

// MARK: - Deprecated
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
    @available(*, deprecated, message: "Use AsyncMiddleware instead")
    public func grouped(_ middleware: Middleware...) -> RoutesBuilder {
        return self.grouped(middleware)
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
    @available(*, deprecated, message: "Use AsyncMiddleware instead")
    public func group(_ middleware: Middleware..., configure: (RoutesBuilder) throws -> ()) rethrows {
        return try self.group(middleware, configure: configure)
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
    @available(*, deprecated, message: "Use AsyncMiddleware instead")
    public func grouped(_ middleware: [Middleware]) -> RoutesBuilder {
        guard middleware.count > 0 else {
            return self
        }
        let asyncMiddleware = middleware.map { AsyncMiddlewareWrapper(middleware: $0) }
        return MiddlewareGroup(root: self, middleware: asyncMiddleware)
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
    @available(*, deprecated, message: "Use AsyncMiddleware instead")
    public func group(_ middleware: [Middleware], configure: (RoutesBuilder) throws -> ()) rethrows {
        let asyncMiddleware = middleware.map { AsyncMiddlewareWrapper(middleware: $0) }
        try configure(MiddlewareGroup(root: self, middleware: asyncMiddleware))
    }
}

// MARK: Private

/// Middleware grouping route.
private final class MiddlewareGroup: RoutesBuilder {
    /// Router to cascade to.
    let root: RoutesBuilder

    /// Additional middleware.
    let middleware: [AsyncMiddleware]

    /// Creates a new `PathGroup`.
    init(root: RoutesBuilder, middleware: [AsyncMiddleware]) {
        self.root = root
        self.middleware = middleware
    }
    
    /// See `HTTPRoutesBuilder`.
    @available(*, deprecated, message: "Use SendableRoute instead")
    func add(_ route: Route) {
        #warning("Fix?")
//        route.responder = self.middleware.makeResponder(chainingTo: route.responder)
        self.root.add(route)
    }
    
    func add(_ route: SendableRoute) {
        var route = route
        route.responder = self.middleware.makeAsyncResponder(chainingTo: route.responder)
        self.root.add(route)
    }
}
