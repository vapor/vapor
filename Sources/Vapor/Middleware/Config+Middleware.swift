import HTTP

extension Config {
    /// Adds a configurable M instance.
    public mutating func addConfigurable<
        M: Middleware
    >(middleware: M, name: String) {
        addConfigurable(instance: middleware, unique: "middleware", name: name)
    }
    
    /// Adds a configurable M class.
    public mutating func addConfigurable<
        M: Middleware & ConfigInitializable
    >(middleware: M.Type, name: String) {
        addConfigurable(class: M.self, unique: "middleware", name: name)
    }
    
    /// Resolves the configured M.
    public func resolveMiddleware() throws -> [Middleware] {
        return try resolveArray(
            unique: "middleware",
            file: "droplet",
            keyPath: ["middleware"],
            as: Middleware.self
        ) { config in
            let log = try config.resolveLog()
            return [
                ErrorMiddleware(config.environment, log),
                DateMiddleware(),
                FileMiddleware(publicDir: config.publicDir)
            ]
        }
    }
}
