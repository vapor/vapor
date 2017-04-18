import Console

extension Config {
    /// Adds a configurable Console instance.
    public mutating func addConfigurable<
        Console: ConsoleProtocol
    >(console: Console, name: String) {
        addConfigurable(instance: console, unique: "console", name: name)
    }
    
    /// Adds a configurable Console class.
    public mutating func addConfigurable<
        Console: ConsoleProtocol & ConfigInitializable
    >(console: Console.Type, name: String) {
        addConfigurable(class: Console.self, unique: "console", name: name)
    }
    
    /// Resolves the configured Console.
    public func resolveConsole() throws -> ConsoleProtocol {
        return try resolve(
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
