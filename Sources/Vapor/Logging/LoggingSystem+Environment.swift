import Logging
import ConsoleKit

extension LoggingSystem {
    public static func bootstrap(from environment: inout Environment, _ factory: @Sendable (Logger.Level) -> (@Sendable (String) -> any LogHandler)) throws {
        let level = try Logger.Level.detect(from: &environment)

        // Bootstrap logger with a factory created by the factoryfactory.
        return LoggingSystem.bootstrap(factory(level))
    }

    public static func bootstrap(from environment: inout Environment) throws {
        try self.bootstrap(from: &environment) { level in
            let console = Terminal()
            return { (label: String) in
                return ConsoleLogger(label: label, console: console, level: level)
            }
        }
    }
}

extension Logging.Logger.Level: Swift.LosslessStringConvertible {
    public init?(_ description: String) { self.init(rawValue: description.lowercased()) }
    public var description: String { self.rawValue }

    public static func detect(from environment: inout Environment) throws -> Logger.Level {
        struct LogSignature: CommandSignature {
            @Option(name: "log", help: "Change log level")
            var level: Logger.Level?
            init() { }
        }

        // Determine log level from environment.
        return try LogSignature(from: &environment.commandInput).level
            ?? Environment.process.LOG_LEVEL
            ?? (environment == .production ? .notice: .info)
    }
}
