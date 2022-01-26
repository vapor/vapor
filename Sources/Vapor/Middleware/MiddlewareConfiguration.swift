/// Configures an application's active `Middleware`.
/// Middleware will be used in the order they are added.
public struct Middlewares {
    /// The configured middleware.
    private var storage: [Middleware]

  
    public enum Position {
      case beginning
      case end
    }
  
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
    public mutating func use(_ middleware: Middleware, at position: Position = .end) {
      switch position {
      case .end:
        self.storage.append(middleware)
      case .beginning:
        self.storage.insert(middleware, at: 0)
      }
    }

    /// Resolves the configured middleware for a given container
    public func resolve() -> [Middleware] {
        return self.storage
    }
}
