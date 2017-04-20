extension Config {
    /// Adds a configurable Server class.
    public func addConfigurable<
        Server: ServerProtocol
    >(server: Server.Type, name: String) {
        addConfigurable(server: ServerFactory<Server>.init, name: name)
    }
    
    /// Adds a configurable Server Factory.
    public func addConfigurable<
        ServerFactory: ServerFactoryProtocol
    >(server: @escaping Config.Lazy<ServerFactory>, name: String) {
        customAddConfigurable(closure: server, unique: "server", name: name)
    }
    
    /// Overrides the configurable Server Factory with this instance.
    public func override<
        ServerFactory: ServerFactoryProtocol
    >(server: ServerFactory) {
        customOverride(instance: server, unique: "server")
    }
    
    /// Resolves the configured ServerFactory.
    public func resolveServer() throws -> ServerFactoryProtocol {
        return try customResolve(
            unique: "server",
            file: "droplet",
            keyPath: ["server"],
            as: ServerFactoryProtocol.self,
            default: ServerFactory<EngineServer>.init
        )
    }
}
