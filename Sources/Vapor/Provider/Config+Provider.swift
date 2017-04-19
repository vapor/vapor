import Configs

extension Config {
    // Storage of all providers added.
    public internal(set) var providers: [Provider] {
        get { return storage["vapor:providers"] as? [Provider] ?? [] }
        set { storage["vapor:providers"] = newValue }
    }
    
    // Adds a provider, booting it with the current config.
    public func addProvider<P: Provider>(_ provider: P) throws {
        guard !providers.contains(where: { type(of: $0) == P.self }) else {
            return
        }
        try provider.boot(self)
        providers.append(provider)
    }
    
    /// Adds a provider type, initializing it first.
    public func addProvider<P: Provider>(_ provider: P.Type) throws {
        let p = try provider.init(config: self)
        try addProvider(p)
    }
}
