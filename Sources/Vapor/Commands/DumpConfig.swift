import Console
import Service
import JSONs

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
        let dump = config[path] ?? .null
        let json = try dump.converted(to: JSON.self)
        let serialized = try json.serialize(prettyPrint: true)
        console.print(serialized.makeString())
    }
}

// MARK: Service

extension DumpConfig: ServiceType {
    /// See Service.name
    public static var serviceName: String {
        return "dump-config"
    }

    public static var serviceSupports: [Any.Type] {
        return [Command.self]
    }

    /// See Service.make
    public static func makeService(for container: Container) throws -> DumpConfig? {
        return try self.init(container.make(ConsoleProtocol.self), container.config)
    }
}
