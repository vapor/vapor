import Sessions

extension Config {
    /// Adds a configurable Sessions.
    public func addConfigurable<
        Sessions: SessionsProtocol
    >(sessions: @escaping Config.Lazy<Sessions>, name: String) {
        customAddConfigurable(closure: sessions, unique: "sessions", name: name)
    }
    
    /// Resolves the configured Sessions.
    public func resolveSessions() throws -> SessionsProtocol {
        return try customResolve(
            unique: "sessions",
            file: "droplet",
            keyPath: ["sessions"],
            as: SessionsProtocol.self,
            default: MemorySessions.init
        )
    }
}

extension MemorySessions: ConfigInitializable {
    public convenience init(config: Config) throws {
        self.init()
    }
}

extension CacheSessions: ConfigInitializable {
    public convenience init(config: Config) throws {
        let cache = try config.resolveCache()
        self.init(cache)
    }
}

extension SessionsMiddleware: ConfigInitializable {
    public convenience init(config: Config) throws {
        let sessions = try config.resolveSessions()
        self.init(sessions)
    }
}
