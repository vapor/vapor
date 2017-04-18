import Console
import Configs

public final class DumpConfig: Command {
    public let id = "dump-config"
    public let help = ["Dumps the configuration for a given key."]
    public var signature: [Argument] = [Value(name: "path")]
    public var console: ConsoleProtocol { return drop.console }
    public unowned let drop: Droplet
    
    public init(_ drop: Droplet) {
        self.drop = drop
    }
    
    public func run(arguments: [String]) throws {
        let path = try value("path", from: arguments)
        let dump = drop.config[path] ?? Config(.null)
        let json = JSON(dump.wrapped)
        let serialized = try json.serialize(prettyPrint: true)
        console.print(serialized.makeString())
    }
}
