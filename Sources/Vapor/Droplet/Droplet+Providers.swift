extension Droplet {
    public func addProvider<P: Provider>(_ provider: P) throws {
        guard !providers.contains(where: { type(of: $0) == P.self }) else {
            return
        }
        try provider.boot(self)
        providers.append(provider)
    }
    
    public func addProvider<P: Provider>(_ provider: P.Type) throws {
        let p = try provider.init(config: config)
        try addProvider(p)
    }
}
