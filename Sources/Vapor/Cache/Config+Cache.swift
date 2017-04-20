import Cache

extension Config {
    /// Adds a configurable Cache instance.
    public func addConfigurable<
        Cache: CacheProtocol
    >(cache: Cache, name: String) {
        customAddConfigurable(instance: cache, unique: "cache", name: name)
    }
    
    /// Adds a configurable Cache class.
    public func addConfigurable<
        Cache: CacheProtocol & ConfigInitializable
    >(cache: Cache.Type, name: String) {
        customAddConfigurable(class: Cache.self, unique: "cache", name: name)
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
