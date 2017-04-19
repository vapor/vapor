extension Config {
    /// Adds a configurable Server class.
    public mutating func addConfigurable<
        Server: ServerProtocol
    >(server: Server.Type, name: String) {
        customAddConfigurable(class: ServerFactory<Server>.self, unique: "server", name: name)
    }
    
    /// Adds a configurable Server Factory instance.
    public mutating func addConfigurable<
        ServerFactory: ServerFactoryProtocol
    >(server: ServerFactory, name: String) {
        customAddConfigurable(instance: server, unique: "server", name: name)
    }
    
    /// Adds a configurable Server Factory class.
    public mutating func addConfigurable<
        ServerFactory: ServerFactoryProtocol & ConfigInitializable
    >(server: ServerFactory.Type, name: String) {
        customAddConfigurable(class: ServerFactory.self, unique: "server", name: name)
    }
    
    /// Overrides the configurable Server Factory with this instance.
    public mutating func override<
        ServerFactory: ServerFactoryProtocol
    >(server: ServerFactory) {
        customOverride(instance: server, unique: "server")
    }
    
    /// Resolves the configured ServerFactory.
    public mutating func resolveServer() throws -> ServerFactoryProtocol {
        return try customResolve(
            unique: "server",
            file: "droplet",
            keyPath: ["server"],
            as: ServerFactoryProtocol.self,
            default: ServerFactory<EngineServer>.init
        )
    }
}
