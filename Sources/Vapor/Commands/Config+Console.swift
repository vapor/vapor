import Console

extension Config {
    /// Adds a configurable Console.
    public func addConfigurable<
        Console: ConsoleProtocol
    >(console: @escaping Config.Lazy<Console>, name: String) {
        customAddConfigurable(closure: console, unique: "console", name: name)
    }
    
    /// Resolves the configured Console.
    public func resolveConsole() throws -> ConsoleProtocol {
        return try customResolve(
            unique: "console",
            file: "droplet",
            keyPath: ["console"],
            as: ConsoleProtocol.self,
            default: Terminal.init
        )
    }
}

extension Terminal: ConfigInitializable {
    public convenience init(config: Config) throws {
        self.init(arguments: config.arguments)
    }
}
