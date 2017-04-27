import HTTP
import Console

extension Config {
    /// Adds a configurable Command.
    public func addConfigurable<
        C: Command
    >(command: @escaping Config.Lazy<C>, name: String) {
        customAddConfigurable(closure: command, unique: "commands", name: name)
    }
    
    /// Overrides the configurable Commands with this array.
    public func override(commands: [Command]) {
        customOverride(instance: commands, unique: "commands")
    }
    
    /// Resolves the configured Command.
    public func resolveCommands() throws -> [Command] {
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

