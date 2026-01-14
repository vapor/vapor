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
    /// - Parameters:
    ///   - config: `ConfigReader` to parse `vapor.env` flag from.
    /// - Returns: The detected environment, or default env.
    public static func detect() throws -> Environment {
        #warning("Implement reading from ConfigReader")
        return .development
    }
    
    /// Performs stripping of user defaults overrides where and when appropriate.
    private static func sanitize(arguments: [String] = ProcessInfo.processInfo.arguments) -> [String] {
        precondition(arguments.count >= 1, "At least one argument (the executable path) is required")
        var arguments = arguments
        let executablePath = [arguments.removeFirst()]
        let executable = executablePath.joined(separator: " ")
        #if Xcode
        // Strip all leading arguments matching the pattern for assignment to the `NSArgumentsDomain`
        // of `UserDefaults`. Matching this pattern means being prefixed by `-NS` or `-Apple` and being
        // followed by a value argument. Since this is mainly just to get around Xcode's habit of
        // passing a bunch of these when no other arguments are specified in a test scheme, we ignore
        // any that don't match the Apple patterns and assume the app knows what it's doing.
        while (arguments.first?.prefix(6) == "-Apple" || arguments.first?.prefix(3) == "-NS"),
              arguments.count > 1 {
            arguments.removeFirst(2)
        }
        #elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        // When tests are invoked directly through SwiftPM using `--filter`, SwiftPM will pass `-XCTest <filter>` to the
        // runner binary, and also the test bundle path unconditionally. These must be stripped for Vapor to be satisfied
        // with the validity of the arguments. We detect this case reliably the hard way, by looking for the `xctest`
        // runner executable and a leading argument with the `.xctest` bundle suffix.
        if executable.hasSuffix("/usr/bin/xctest") {
            if arguments.first?.lowercased() == "-xctest" && arguments.count > 1 {
                arguments.removeFirst(2)
            }
            if arguments.first?.hasSuffix(".xctest") ?? false {
                arguments.removeFirst()
            }
        }
        #endif
        return executablePath + arguments
    }
    
    // MARK: - Presets

    /// An environment for deploying your application to consumers.
    public static var production: Environment { .init(name: "production") }

    /// An environment for developing your application.
    public static var development: Environment { .init(name: "development") }

    /// An environment for testing your application.
    ///
    /// Performs an explicit sanitization step because this preset is often used directly in unit tests, without the
    /// benefit of the logic usually invoked through either form of `detect()`. This means that when `--env test` is
    /// explicitly specified, the sanitize logic is run twice, but this should be harmless.
    public static var testing: Environment { .init(name: "testing", arguments: sanitize()) }

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

    /// The command-line arguments for this ``Environment``.
    public var arguments: [String]
    
    // MARK: - Init

    /// Create a new ``Environment``.
    public init(name: String, arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.name = name
        self.arguments = arguments
    }
}
