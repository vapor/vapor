import Console

extension Config {
    /// Adds a configurable Console instance.
    public func addConfigurable<
        Console: ConsoleProtocol
    >(console: Console, name: String) {
        customAddConfigurable(instance: console, unique: "console", name: name)
    }
    
    /// Adds a configurable Console class.
    public func addConfigurable<
        Console: ConsoleProtocol & ConfigInitializable
    >(console: Console.Type, name: String) {
        customAddConfigurable(class: Console.self, unique: "console", name: name)
    }
    
    /// Overrides the configurable Console with this instance.
    public func override<
        Console: ConsoleProtocol
    >(console: Console) {
        customOverride(instance: console, unique: "console")
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
