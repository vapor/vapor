extension Droplet {
    public func addProvider(_ provider: Provider) throws {
        guard !providers.contains(where: { $0.name == provider.name }) else {
            return
        }
        try provider.boot(self)
        providers.append(provider)
    }

    public func addProvider(_ provider: Provider.Type) throws {
        let p = try provider.init(config: config)
        try addProvider(p)
    }
}
