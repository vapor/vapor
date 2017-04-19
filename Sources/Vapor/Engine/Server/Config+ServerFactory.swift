extension Config {
    /// Adds a configurable Server class.
    public mutating func addConfigurable<
        Server: ServerProtocol
    >(server: Server.Type, name: String) {
        addConfigurable(class: ServerFactory<Server>.self, unique: "server", name: name)
    }
    
    /// Adds a configurable Server Factory instance.
    public mutating func addConfigurable<
        ServerFactory: ServerFactoryProtocol
    >(server: ServerFactory, name: String) {
        addConfigurable(instance: server, unique: "server", name: name)
    }
    
    /// Adds a configurable Server Factory class.
    public mutating func addConfigurable<
        ServerFactory: ServerFactoryProtocol & ConfigInitializable
    >(server: ServerFactory.Type, name: String) {
        addConfigurable(class: ServerFactory.self, unique: "server", name: name)
    }
    
    /// Resolves the configured ServerFactory.
    public func resolveServer() throws -> ServerFactoryProtocol {
        return try resolve(
            unique: "server",
            file: "droplet",
            keyPath: ["server"],
            as: ServerFactoryProtocol.self,
            default: ServerFactory<EngineServer>.init
        )
    }
}
