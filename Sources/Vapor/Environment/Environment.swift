import Configuration
import Foundation

/// The environment the application is running in, i.e., production, dev, etc. All `Container`s will have
/// an `Environment` that can be used to dynamically register and configure services.
///
///     switch env {
///     case .production:
///         app.http.server.configuration = ...
///     default: break
///     }
///
/// The `Environment` can also be used to retrieve variables from the Process' ENV.
///
///     print(Environment.get("DB_PASSWORD"))
///
public struct Environment: Sendable, Equatable {
    // MARK: - Detection
    
    /// Detects the environment from `ConfigReader`. Parses the `vapor.env` flag.
    ///
    /// - Parameter config: `ConfigReader` to parse `vapor.env` flag from.
    /// - Returns: The detected environment, or default env.
    ///
    /// ## Configuration keys:
    /// - `vapor.env`: (string, optional, default: `.development`): The name of the environment to use.
    public static func detect(from config: ConfigReader) throws -> Environment {
        config.string(forKey: "vapor.env", as: Environment.self, default: .development)
    }
    
    // MARK: - Presets

    /// An environment for deploying your application to consumers.
    public static var production: Environment { .init(name: "production") }

    /// An environment for developing your application.
    public static var development: Environment { .init(name: "development") }

    /// An environment for testing your application.
    public static var testing: Environment { .init(name: "testing") }

    /// Creates a custom environment.
    public static func custom(name: String) -> Environment { .init(name: name) }

    // MARK: - Env

    /// Gets a key from the process environment
    public static func get(_ key: String) -> String? {
        return ProcessInfo.processInfo.environment[key]
    }

    /// The current process of the environment.
    public static var process: Process {
        return Process()
    }
    
    // MARK: - Equatable

    // See `Equatable.==(_:_:)`.
    public static func ==(lhs: Environment, rhs: Environment) -> Bool {
        return lhs.name == rhs.name
    }

    // MARK: - Properties

    /// The environment's unique name.
    public let name: String

    /// `true` if this environment is meant for production use cases.
    ///
    /// This usually means reducing logging, disabling debug information, and sometimes
    /// providing warnings about configuration states that are not suitable for production.
    ///
    /// - Warning: This value is determined at compile time by configuration; it is not
    ///   based on the actual environment name. This can lead to unexpected results, such
    ///   as `Environment.production.isRelease == false`. This is done intentionally to
    ///   allow scenarios, such as testing production environment behaviors while retaining
    ///   availability of debug information.
    public var isRelease: Bool { !_isDebugAssertConfiguration() }
    
    // MARK: - Init

    /// Create a new ``Environment``.
    public init(name: String) {
        self.name = name
    }
}

extension Environment: ExpressibleByConfigString {
    public init?(configString: String) {
        switch configString {
        case "prod", "production": self = .production
        case "dev", "development": self = .development
        case "test", "testing": self = .testing
        default: self = .init(name: configString)
        }
    }

    public var description: String {
        self.name
    }
}
