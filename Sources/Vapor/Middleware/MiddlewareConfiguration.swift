@available(*, deprecated, renamed: "Middlewares")
public typealias MiddlewareConfiguration = Middlewares

/// Configures an application's active `Middleware`.
/// Middleware will be used in the order they are added.
public struct Middlewares {
    /// The configured middleware.
    private var storage: [Middleware]

    /// Create a new, empty `MiddlewareConfig`.
    public init() {
        self.storage = []
    }

    /// Adds a pre-initialized `Middleware` instance.
    ///
    ///     var middlewareConfig = MiddlewareConfig.default()
    ///     middlewareConfig.use(fooMiddleware)
    ///     services.register(middlewareConfig)
    ///
    /// - warning: Ensure the `Middleware` is thread-safe when using this method.
    ///            Otherwise, use the type-based method and register the `Middleware`
    ///            using factory method to `Services`.
    public mutating func use(_ middleware: Middleware) {
        self.storage.append(middleware)
    }

    /// Resolves the configured middleware for a given container
    internal func resolve() -> [Middleware] {
        return self.storage
    }
}
