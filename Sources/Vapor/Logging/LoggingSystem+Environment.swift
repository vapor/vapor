import Logging
import ConsoleLogger
import Configuration

extension LoggingSystem {
    public static func bootstrap(from config: ConfigReader, _ factory: @Sendable (Logger.Level) -> (@Sendable (String) -> any LogHandler)) throws {
        let level = try Logger.Level.detect(from: config)

        // Bootstrap logger with a factory created by the factoryfactory.
        return LoggingSystem.bootstrap(factory(level))
    }

    public static func bootstrap(from config: ConfigReader) throws {
        try self.bootstrap(from: config) { level in
            return { (label: String) in
                ConsoleLogger(label: label, level: level)
            }
        }
    }
}

extension Logger.Level: @retroactive CustomStringConvertible {}
extension Logger.Level: @retroactive LosslessStringConvertible {}

extension Logging.Logger.Level {
    public init?(_ description: String) { self.init(rawValue: description.lowercased()) }
    public var description: String { self.rawValue }

    public static func detect(from config: ConfigReader) throws -> Logger.Level {
        config.string(forKey: "log.level", as: Logger.Level.self, default: .info)
    }
}
