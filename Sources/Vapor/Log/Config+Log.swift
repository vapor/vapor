extension Config {
    /// Adds a configurable Log.
    public func addConfigurable<
        Log: LogProtocol
    >(log: @escaping Config.Lazy<Log>, name: String) {
        customAddConfigurable(closure: log, unique: "log", name: name)
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
