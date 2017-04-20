extension Config {
    /// Adds a configurable Log instance.
    public func addConfigurable<
        Log: LogProtocol
    >(log: Log, name: String) {
        customAddConfigurable(instance: log, unique: "log", name: name)
    }
    
    /// Adds a configurable Log class.
    public func addConfigurable<
        Log: LogProtocol & ConfigInitializable
    >(log: Log.Type, name: String) {
        customAddConfigurable(class: Log.self, unique: "log", name: name)
    }
    
    /// Resolves the configured Log.
    public func resolveLog() throws -> LogProtocol {
        return try customResolve(
            unique: "log",
            file: "droplet",
            keyPath: ["log"],
            as: LogProtocol.self,
            default: ConsoleLogger.init
        )
    }
}
