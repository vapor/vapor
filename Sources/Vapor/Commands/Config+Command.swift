import HTTP
import Console

extension Config {
    /// Adds a configurable Command instance.
    public mutating func addConfigurable<
        C: Command
    >(command: C, name: String) {
        customAddConfigurable(instance: command, unique: "command", name: name)
    }
    
    /// Adds a configurable Command class.
    public mutating func addConfigurable<
        C: Command & ConfigInitializable
    >(command: C.Type, name: String) {
        customAddConfigurable(class: C.self, unique: "command", name: name)
    }
    
    /// Resolves the configured Command.
    public mutating func resolveCommands() throws -> [Command] {
        return try customResolveArray(
            unique: "commands",
            file: "droplet",
            keyPath: ["commands"],
            as: Command.self
        ) { config in
            return [Command]()
        }
    }
}

