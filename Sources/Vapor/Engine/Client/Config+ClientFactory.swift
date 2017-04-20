extension Config {
    /// Adds a configurable Client class.
    public func addConfigurable<
        Client: ClientProtocol
    >(client: Client.Type, name: String) {
        addConfigurable(client: ClientFactory<Client>.init, name: name)
    }
    
    /// Adds a configurable Client Factory.
    public func addConfigurable<
        ClientFactory: ClientFactoryProtocol
    >(client: @escaping Config.Lazy<ClientFactory>, name: String) {
        customAddConfigurable(closure: client, unique: "client", name: name)
    }
    
    /// Resolves the configured ClientFactory.
    public func resolveClient() throws -> ClientFactoryProtocol {
        return try customResolve(
            unique: "client",
            file: "droplet",
            keyPath: ["client"],
            as: ClientFactoryProtocol.self,
            default: ClientFactory<EngineClient>.init
        )
    }
}
