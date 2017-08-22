import HTTP
import Service

/// Desired middleware configuration
public struct MiddlewareConfig {
    let desired: [Middleware.Type]

    public init(_ desired: [Middleware.Type]) {
        self.desired = desired
    }
}

// MARK: Service

extension MiddlewareConfig {
    /// Resolves the desired middleware for a given container
    func resolve(for container: Container) throws -> [Middleware] {
        return try desired.map { desired in
            try container.unsafeMake(desired, for: MiddlewareConfig.self) as! Middleware
        }
    }
}
