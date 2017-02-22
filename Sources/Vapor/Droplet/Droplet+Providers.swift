extension Droplet {
    public func addProvider(_ provider: Provider) throws {
        try provider.boot(self)
        providers.append(provider)
    }

    public func addProvider(_ provider: Provider.Type) throws {
        let p = try provider.init(config: config)
        try addProvider(p)
    }
}
