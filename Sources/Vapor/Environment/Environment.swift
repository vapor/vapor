import ConsoleKit

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
public struct Environment: Equatable {
    
    // MARK: - Detection
    
    /// Detects the environment from `CommandLine.arguments`. Invokes `detect(from:)`.
    /// - parameters:
    ///     - arguments: Command line arguments to detect environment from.
    /// - returns: The detected environment, or default env.
    public static func detect(arguments: [String] = CommandLine.arguments) throws -> Environment {
        var commandInput = CommandInput(arguments: arguments)
        return try Environment.detect(from: &commandInput)
    }
    
    /// Detects the environment from `CommandInput`. Parses the `--env` flag, with the
    /// `VAPOR_ENV` environment variable as a fallback.
    /// - parameters:
    ///     - arguments: `CommandInput` to parse `--env` flag from.
    /// - returns: The detected environment, or default env.
    public static func detect(from commandInput: inout CommandInput) throws -> Environment {
        self.sanitize(commandInput: &commandInput)
        
        struct EnvironmentSignature: CommandSignature {
            @Option(name: "env", short: "e", help: "Change the application's environment")
            var environment: String?
        }

        var env: Environment
        switch try EnvironmentSignature(from: &commandInput).environment ??
               Environment.process.VAPOR_ENV
        {
            case "prod", "production": env = .production
            case "dev", "development", .none: env = .development
            case "test", "testing": env = .testing
            case .some(let name): env = .init(name: name)
        }
        env.commandInput = commandInput
        return env
    }
    
    /// Performs stripping of user defaults overrides where and when appropriate.
    private static func sanitize(commandInput: inout CommandInput) {
        #if Xcode
        // Strip all leading arguments matching the pattern for assignment to the `NSArgumentsDomain`
        // of `UserDefaults`. Matching this pattern means being prefixed by `-NS` or `-Apple` and being
        // followed by a value argument. Since this is mainly just to get around Xcode's habit of
        // passing a bunch of these when no other arguments are specified in a test scheme, we ignore
        // any that don't match the Apple patterns and assume the app knows what it's doing.
        //
        // Note that we also perform this behavior more forcefully when the `.testing` environment is
        // constructed, even if it means
        while (commandInput.arguments.first?.prefix(6) == "-Apple" || commandInput.arguments.first?.prefix(3) == "-NS"),
              commandInput.arguments.count > 1 {
            commandInput.arguments.removeFirst(2)
        }
        #elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        // When tests are invoked directly through SwiftPM using `--filter`, SwiftPM will pass `-XCTest <filter>` to the
        // runner binary, and also the test bundle path unconditionally. These must be stripped for Vapor to be satisifed
        // with the validity of the arguments. We detect this case reliably the hard way, by looking for the `xctest`
        // runner executable and a leading argument with the `.xctest` bundle suffix.
        if commandInput.executable.hasSuffix("/usr/bin/xctest") {
            if commandInput.arguments.first?.lowercased() == "-xctest" && commandInput.arguments.count > 1 {
                commandInput.arguments.removeFirst(2)
            }
            if commandInput.arguments.first?.hasSuffix(".xctest") ?? false {
                commandInput.arguments.removeFirst()
            }
        }
        #endif
    }
    
    /// Invokes `sanitize(commandInput:)` over a set of raw arguments and returns the
    /// resulting arguments, including the executable path.
    private static func sanitizeArguments(_ arguments: [String] = CommandLine.arguments) -> [String] {
        var commandInput = CommandInput(arguments: arguments)
        sanitize(commandInput: &commandInput)
        return commandInput.executablePath + commandInput.arguments
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
    public static var testing: Environment { .init(name: "testing", arguments: sanitizeArguments()) }

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

    /// See `Equatable`
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
    ///   based on the actual environment name. This can lead to unxpected results, such
    ///   as `Environment.production.isRelease == false`. This is done intentionally to
    ///   allow scenarios, such as testing production environment behaviors while retaining
    ///   availability of debug information.
    public var isRelease: Bool { !_isDebugAssertConfiguration() }

    /// The command-line arguments for this `Environment`.
    public var arguments: [String]

    /// Exposes the `Environment`'s `arguments` property as a `CommandInput`.
    public var commandInput: CommandInput {
        get { return CommandInput(arguments: arguments) }
        set { arguments = newValue.executablePath + newValue.arguments }
    }
    
    // MARK: - Init

    /// Create a new `Environment`.
    public init(name: String, arguments: [String] = CommandLine.arguments) {
        self.name = name
        self.arguments = arguments
    }
}
