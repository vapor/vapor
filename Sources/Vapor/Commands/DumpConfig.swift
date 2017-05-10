import Console
import Configs

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
