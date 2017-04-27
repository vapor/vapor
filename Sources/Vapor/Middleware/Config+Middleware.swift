import HTTP

extension Config {
    /// Adds a configurable M instance.
    public func addConfigurable<
        M: Middleware
    >(middleware: @escaping Config.Lazy<M>, name: String) {
        customAddConfigurable(closure: middleware, unique: "middleware", name: name)
    }
    
    /// Adds a configurable M instance.
    public func addConfigurable<
        M: Middleware
    >(middleware: M, name: String) {
        customAddConfigurable(closure: { _ in middleware }, unique: "middleware", name: name)
    }
    
    /// Resolves the configured M.
    public func resolveMiddleware() throws -> [Middleware] {
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
    public convenience init(config: Config) throws {
        self.init()
    }
}

extension FileMiddleware: ConfigInitializable {
    public convenience init(config: Config) throws {
        self.init(publicDir: config.publicDir)
    }
}
