/// Configures an application's active `Middleware`.
/// Middleware will be used in the order they are added.
public struct MiddlewareConfiguration {
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
    public mutating func use<M>(_ middleware: M) where M: Middleware {
        storage.append(middleware)
    }

    /// Resolves the configured middleware for a given container
    internal func resolve() throws -> [Middleware] {
        return self.storage
    }
}
