extension Config {
    /// Adds a configurable Client class.
    public mutating func addConfigurable<
        Client: ClientProtocol
    >(client: Client.Type, name: String) {
        customAddConfigurable(class: ClientFactory<Client>.self, unique: "client", name: name)
    }
    
    /// Adds a configurable Client Factory instance.
    public mutating func addConfigurable<
        ClientFactory: ClientFactoryProtocol
    >(client: ClientFactory, name: String) {
        customAddConfigurable(instance: client, unique: "client", name: name)
    }
    
    /// Adds a configurable Client Factory class.
    public mutating func addConfigurable<
        ClientFactory: ClientFactoryProtocol & ConfigInitializable
    >(client: ClientFactory.Type, name: String) {
        customAddConfigurable(class: ClientFactory.self, unique: "client", name: name)
    }
    
    /// Resolves the configured ClientFactory.
    public mutating func resolveClient() throws -> ClientFactoryProtocol {
        return try customResolve(
            unique: "client",
            file: "droplet",
            keyPath: ["client"],
            as: ClientFactoryProtocol.self,
            default: ClientFactory<EngineClient>.init
        )
    }
}
