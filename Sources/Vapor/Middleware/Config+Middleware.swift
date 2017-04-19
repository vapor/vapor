import HTTP

extension Config {
    /// Adds a configurable M instance.
    public mutating func addConfigurable<
        M: Middleware
    >(middleware: M, name: String) {
        customAddConfigurable(instance: middleware, unique: "middleware", name: name)
    }
    
    /// Adds a configurable M class.
    public mutating func addConfigurable<
        M: Middleware & ConfigInitializable
    >(middleware: M.Type, name: String) {
        customAddConfigurable(class: M.self, unique: "middleware", name: name)
    }
    
    /// Overrides the configurable Console with this instance.
    public mutating func override(middleware: [Middleware]) {
        customOverride(instance: middleware, unique: "middleware")
    }
    
    /// Resolves the configured M.
    public mutating func resolveMiddleware() throws -> [Middleware] {
        return try customResolveArray(
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

extension DateMiddleware: ConfigInitializable {
    public convenience init(config: inout Config) throws {
        self.init()
    }
}

extension FileMiddleware: ConfigInitializable {
    public convenience init(config: inout Config) throws {
        self.init(publicDir: config.publicDir)
    }
}
