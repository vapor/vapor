extension Environment {
    @available(*, deprecated, message: """
    Use `Environment.detect()` or `Environment.init()` to create environments.
    Use `environment.name` when comparing environments.
    """)
    public static var production: Environment {
        .detect(default: .production)
    }

    @available(*, deprecated, message: """
    Use `Environment.detect()` or `Environment.init()` to create environments.
    Use `environment.name` when comparing environments.
    """)
    public static var development: Environment {
        .detect(default: .development)
    }

    @available(*, deprecated, message: """
    Use `Environment.detect()` or `Environment.init()` to create environments.
    Use `environment.name` when comparing environments.
    """)
    public static var testing: Environment {
        .detect(default: .testing)
    }

    @available(*, deprecated, message: """
    Use `Environment.detect()` or `Environment.init()` to create environments.
    Use `environment.name` when comparing environments.
    """)
    public static func custom(name: String) -> Environment {
        .detect(default: .init(string: name))
    }

    @available(*, deprecated, message: "Use method that accepts Environment.Name instead of String.")
    public init(name: String, arguments: [String] = CommandLine.arguments) {
        self.init(name: .init(string: name), arguments: arguments)
    }
}
