import Console
import Configs

/// Command for dumping compiled config to the console.
public final class DumpConfig: Command {
    public let id = "dump-config"
    public let help = ["Dumps the configuration for a given key."]
    public let signature: [Argument] = [Value(name: "path")]
    public let console: ConsoleProtocol
    public let config: Config
    
    public init(_ console: ConsoleProtocol, _ config: Config) {
        self.console = console
        self.config = config
    }
    
    public func run(arguments: [String]) throws {
        let path = try value("path", from: arguments)
        let dump = config[path] ?? Config(.null)
        let json = JSON(dump.wrapped)
        let serialized = try json.serialize(prettyPrint: true)
        console.print(serialized.makeString())
    }
}

// MARK: Service

extension DumpConfig: Service {
    /// See Service.name
    public static var name: String {
        return "dump-config"
    }

    /// See Service.make
    public static func make(for drop: Droplet) throws -> DumpConfig? {
        return try self.init(drop.make(ConsoleProtocol.self), drop.config)
    }
}
