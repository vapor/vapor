extension LoggingSystem {
    public static func bootstrap(from environment: inout Environment) throws {
        try LoggingSystem.bootstrap(
            console: Terminal(),
            level: environment.commandInput.parseOption(
                value: Logger.Level.self,
                name: "log"
                ) ?? (environment == .production ? .error: .info)
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

private extension CommandInput {
    mutating func parseOption<Value>(
        value: Value.Type,
        name: String,
        short: Character? = nil
        ) throws -> Value?
        where Value: LosslessStringConvertible
    {
        let option = Option<Value>(name: name, short: short, type: .value, help: "")
        return try self.parse(option: option)
            .flatMap { Value.init($0) }
    }
}
