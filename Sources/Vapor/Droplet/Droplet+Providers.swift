extension Droplet {
    public func add(_ provider: Provider) {
        provider.boot(self)
        provider.afterInit(self)
        providers.append(provider)
    }

    public func add(_ provider: Provider.Type) throws {
        let p = try provider.init(config: config)
        add(p)
    }
}
