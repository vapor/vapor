extension Config {
    /// Adds a configurable Client class.
    public mutating func addConfigurable<
        Client: ClientProtocol
    >(client: Client.Type, name: String) {
        addConfigurable(class: ClientFactory<Client>.self, unique: "client", name: name)
    }
    
    /// Adds a configurable Client Factory instance.
    public mutating func addConfigurable<
        ClientFactory: ClientFactoryProtocol
    >(client: ClientFactory, name: String) {
        addConfigurable(instance: client, unique: "client", name: name)
    }
    
    /// Adds a configurable Client Factory class.
    public mutating func addConfigurable<
        ClientFactory: ClientFactoryProtocol & ConfigInitializable
    >(client: ClientFactory.Type, name: String) {
        addConfigurable(class: ClientFactory.self, unique: "client", name: name)
    }
    
    /// Resolves the configured ClientFactory.
    public func resolveClientFactory() throws -> ClientFactoryProtocol {
        return try resolve(
            unique: "client",
            file: "droplet",
            keyPath: ["client"],
            as: ClientFactoryProtocol.self,
            default: ClientFactory<EngineClient>.init
        )
    }
}
