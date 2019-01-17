extension HTTPRoutesBuilder {
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
    public func grouped(_ middleware: HTTPMiddleware...) -> HTTPRoutesBuilder {
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
    public func group(_ middleware: HTTPMiddleware..., configure: (HTTPRoutesBuilder) -> ()) {
        return self.group(middleware, configure: configure)
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
    public func grouped(_ middleware: [HTTPMiddleware]) -> HTTPRoutesBuilder {
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
    public func group(_ middleware: [HTTPMiddleware], configure: (HTTPRoutesBuilder) -> ()) {
        configure(MiddlewareGroup(root: self, middleware: middleware))
    }
}

// MARK: Private

/// Middleware grouping route.
private final class MiddlewareGroup: HTTPRoutesBuilder {
    /// Router to cascade to.
    let root: HTTPRoutesBuilder

    /// See `HTTPRoutesBuilder`.
    var eventLoop: EventLoop {
        return self.root.eventLoop
    }

    /// Additional middleware.
    let middleware: [HTTPMiddleware]

    /// Creates a new `PathGroup`.
    init(root: HTTPRoutesBuilder, middleware: [HTTPMiddleware]) {
        self.root = root
        self.middleware = middleware
    }
    
    /// See `HTTPRoutesBuilder`.
    func add(_ route: HTTPRoute) {
        route.responder = self.middleware.makeResponder(chainingTo: route.responder)
        self.root.add(route)
    }
}
