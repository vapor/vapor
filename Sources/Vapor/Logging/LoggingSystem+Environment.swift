extension LoggingSystem {
    public static func bootstrap(from environment: inout Environment, factoryfactory: (Logger.Level) -> (String) -> LogHandler) throws {
        struct LogSignature: CommandSignature {
            @Option(name: "log", help: "Change log level")
            var level: Logger.Level?
            init() { }
        }

        // Determine log level from environment.
        let level = try LogSignature(from: &environment.commandInput).level
            ?? Environment.process.LOG_LEVEL
            ?? (environment == .production ? .notice: .info)

        // Disable stack traces if log level > debug.
        if level > .debug {
            StackTrace.isCaptureEnabled = false
        }

        // Bootstrap logger with a factory created by the factoryfactory.
        return LoggingSystem.bootstrap(factoryfactory(level))
    }

    public static func bootstrap(from environment: inout Environment) throws {
        try bootstrap(from: &environment, factoryfactory: { level in
            let console = Terminal()
            return { (label: String) in
                return ConsoleLogger(label: label, console: console, level: level)
            }
        })
    }
}

extension Logger.Level: LosslessStringConvertible {
    public init?(_ description: String) {
        switch description.lowercased() {
        case "trace": self = .trace
        case "debug": self = .debug
        case "info": self = .info
        case "notice": self = .notice
        case "warning": self = .warning
        case "error": self = .error
        case "critical": self = .critical
        default: return nil
        }
    }

    public var description: String {
        switch self {
        case .trace: return "trace"
        case .debug: return "debug"
        case .info: return "info"
        case .notice: return "notice"
        case .warning: return "warning"
        case .error: return "error"
        case .critical: return "critical"
        }
    }
}
