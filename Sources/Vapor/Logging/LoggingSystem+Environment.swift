extension LoggingSystem {
    public static func bootstrap(from environment: inout Environment) throws {
        struct LogSignature: CommandSignature {
            @Option(name: "log", help: "Change log level")
            var level: Logger.Level?
            init() { }
        }

        // Determine log level from environment.
        let level = try LogSignature(from: &environment.commandInput).level
            ?? Environment.process.LOG_LEVEL
            ?? (environment == .production ? .notice: .info)

        // Disable stack traces if log level > trace.
        if level > .trace {
            StackTrace.isCaptureEnabled = false
        }

        // Bootstrap logger to use Terminal.
        return LoggingSystem.bootstrap(console: Terminal(), level: level)
    }
}

extension Logger.Level: LosslessStringConvertible {
    public init?(_ description: String) { self.init(rawValue: description.lowercased()) }
    public var description: String { self.rawValue }
}
