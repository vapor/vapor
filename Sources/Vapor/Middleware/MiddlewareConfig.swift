/// Configures an application's active `Middleware`.
/// Middleware will be used in the order they are added.
public struct MiddlewareConfig: ServiceType {
    /// Creates a new `MiddlewareConfig` with default settings.
    ///
    /// Currently this includes `DateMiddleware` and default `ErrorMiddleware` but this
    /// may change in the future.
    public static func `default`() -> MiddlewareConfig {
        var config = MiddlewareConfig()
        config.use(ErrorMiddleware.self)
        return config
    }

    /// See `ServiceType`.
    public static func makeService(for worker: Container) throws -> MiddlewareConfig {
        return .default()
    }

    /// The configured middleware.
    private var storage: [(Container) throws -> Middleware]

    /// Create a new, empty `MiddlewareConfig`.
    public init() {
        self.storage = []
    }

    /// Adds the supplied `Middleware` type.
    ///
    ///     var middlewareConfig = MiddlewareConfig.default()
    ///     middlewareConfig.use(FooMiddleware.self)
    ///     services.register(middlewareConfig)
    ///
    /// The service container will be asked to create this type upon application boot.
    public mutating func use<M>(_ type: M.Type) where M: Middleware {
        storage.append { try $0.make(M.self) }
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
        storage.append { _ in middleware }
    }

    /// Resolves the configured middleware for a given container
    internal func resolve(for container: Container) throws -> [Middleware] {
        return try storage.map { try $0(container) }
    }
}
