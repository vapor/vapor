import HTTP
import Service

/// Configures application middleware.
/// Middleware will be used in the order they are added.
public struct MiddlewareConfig {
    /// Lazily initializes a middleware using container.
    typealias LazyMiddleware = (Container) throws -> Middleware

    /// The configured middleware.
    var storage: [LazyMiddleware]

    /// Create a new middleware config.
    public init() {
        self.storage = []
    }

    /// Adds the supplied middleware type.
    /// The service container will be asked to create this
    /// middleware type upon application boot.
    public mutating func use<M: Middleware>(_ type: M.Type) {
        storage.append({ container in
            return try container.make(M.self, for: MiddlewareConfig.self)
        })
    }

    /// Adds the supplied middleware.
    public mutating func use<M: Middleware>(_ middleware: M) {
        storage.append({ container in
            return middleware
        })
    }
}

// MARK: Service

extension MiddlewareConfig {
    /// Resolves the desired middleware for a given container
    internal func resolve(for container: Container) throws -> [Middleware] {
        return try storage.map { lazy in
            return try lazy(container)
        }
    }
    
    public static func `default`() -> MiddlewareConfig {
        var config = MiddlewareConfig()
        config.use(FileMiddleware.self)
        config.use(DateMiddleware.self)
        config.use(ErrorMiddleware.self)
        return config
    }
}
