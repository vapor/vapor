import Cache

extension Config {
    /// Adds a configurable Cache.
    public func addConfigurable<
        Cache: CacheProtocol
    >(cache: @escaping Config.Lazy<Cache>, name: String) {
        customAddConfigurable(closure: cache, unique: "cache", name: name)
    }
    
    /// Resolves the configured Cache.
    public func resolveCache() throws -> CacheProtocol {
        return try customResolve(
            unique: "cache",
            file: "droplet",
            keyPath: ["cache"],
            as: CacheProtocol.self,
            default: MemoryCache.init
        )
    }
}

extension MemoryCache: ConfigInitializable {
    public convenience init(config: Config) throws {
        self.init()
    }
}
