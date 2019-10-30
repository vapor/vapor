extension LoggingSystem {
    public static func bootstrap(from environment: inout Environment) throws {
        struct LogSignature: CommandSignature {
            @Option(name: "log", help: "Change log level")
            var level: Logger.Level?
            init() { }
        }
        try LoggingSystem.bootstrap(
            console: Terminal(),
            level: LogSignature(from: &environment.commandInput).level
                ?? (environment == .production ? .notice: .info)
        )
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
