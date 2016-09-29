extension Droplet {
    public func addProvider(_ provider: Provider) {
        provider.boot(self)
        provider.afterInit(self)
        providers.append(provider)
    }

    public func addProvider(_ provider: Provider.Type) throws {
        let p = try provider.init(config: config)
        addProvider(p)
    }
}
