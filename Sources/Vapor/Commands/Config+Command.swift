import HTTP
import Console

extension Config {
    /// Adds a configurable Command.
    public func addConfigurable<
        C: Command
    >(command: @escaping Config.Lazy<C>, name: String) {
        customAddConfigurable(closure: command, unique: "commands", name: name)
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

