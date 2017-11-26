public enum Environment {
    case production
    case development
    case testing
    case custom(String)
}

extension Environment {
    public init(string: String) {
        switch string {
        case "prod", "production":
            self = .production
        case "dev", "development":
            self = .development
        case "test", "testing":
            self = .testing
        default:
            self = .custom(string)
        }
    }
}

extension Environment: Equatable {
    public static func ==(lhs: Environment, rhs: Environment) -> Bool {
        switch (lhs, rhs) {
        case (.production, .production):
            return true
        case (.development, .development):
            return true
        case (.testing, .testing):
            return true
        case (.custom(let a), .custom(let b)):
            return a == b
        default:
            return false
        }
    }
}

private let commandLineKey = "--env="

extension Environment {
    public static func detect(arguments: [String] = CommandLine.arguments) -> Environment {
        var env: Environment = .development

        for arg in arguments {
            if arg.hasPrefix(commandLineKey) {
                var string = arg
                string.removeFirst(commandLineKey.count)
                env = Environment(string: string)
            }
        }

        return env
    }
}
