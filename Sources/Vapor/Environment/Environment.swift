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
    // MARK: - Name

    public struct Name: Equatable {
        // TODO: expressible by string literal

        public static var production: Self {
            .init(string: "production")
        }

        public static var development: Self {
            .init(string: "development")
        }

        public static var testing: Self {
            .init(string: "testing")
        }

        public let string: String

        public init(string: String) {
            self.string = string
        }

        init(canonicalizing string: String) {
            switch string {
            case "prod", "production":
                self = .production
            case "dev", "development":
                self = .development
            case "test", "testing":
                self = .testing
            default:
                self = .init(string: string)
            }
        }
    }

    // MARK: - Detection
    
    /// Detects the environment from `CommandLine.arguments`. Invokes `detect(from:)`.
    /// - parameters:
    ///     - default: Default environment name to use if none detected.
    ///     - arguments: Command line arguments to detect environment from.
    ///     - sanitize: If true, extraneous Swift / Xcode arguments will be removed automatically.
    /// - returns: The detected environment, or default env.
    public static func detect(
        default name: Name = .development,
        arguments: [String] = CommandLine.arguments,
        sanitize: Bool = true
    ) -> Environment {
        var commandInput = CommandInput(arguments: arguments)
        return .detect(default: name, from: &commandInput, sanitize: sanitize)
    }
    
    /// Detects the environment from `CommandInput`. Parses the `--env` flag, with the
    /// `VAPOR_ENV` environment variable as a fallback.
    ///
    /// - parameters:
    ///     - default: Default environment name to use if none detected.
    ///     - arguments: `CommandInput` to parse `--env` flag from.
    ///     - sanitize: If true, extraneous Swift / Xcode arguments will be removed automatically.
    /// - returns: The detected environment, or default env.
    public static func detect(
        default name: Name = .development,
        from commandInput: inout CommandInput,
        sanitize: Bool = true
    ) -> Environment {
        if sanitize {
            commandInput.sanitize()
        }
        
        struct EnvironmentSignature: CommandSignature {
            @Option(name: "env", short: "e", help: "Change the application's environment")
            var environment: String?
        }

        // This cannot throw since we're only loading options.
        let name = try! EnvironmentSignature(
            from: &commandInput
        ).environment.flatMap(Name.init(canonicalizing:))
            ?? Environment.process.VAPOR_ENV.flatMap(Name.init(canonicalizing:))
            ?? name

        var env = Environment(name: name, arguments: [])
        env.commandInput = commandInput
        return env
    }
    
    // MARK: - Presets


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
    public let name: Name

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
        set { self.arguments = newValue.executablePath + newValue.arguments }
    }
    
    // MARK: - Init

    /// Create a new `Environment`.
    public init(name: Name, arguments: [String] = ["vapor"]) {
        self.name = name
        self.arguments = arguments
    }
}

private extension CommandInput {
    /// Performs stripping of user defaults overrides where and when appropriate.
    mutating func sanitize() {
        #if Xcode
        // Strip all leading arguments matching the pattern for assignment to the `NSArgumentsDomain`
        // of `UserDefaults`. Matching this pattern means being prefixed by `-NS` or `-Apple` and being
        // followed by a value argument. Since this is mainly just to get around Xcode's habit of
        // passing a bunch of these when no other arguments are specified in a test scheme, we ignore
        // any that don't match the Apple patterns and assume the app knows what it's doing.
        while (self.arguments.first?.prefix(6) == "-Apple" || self.arguments.first?.prefix(3) == "-NS"),
              self.arguments.count > 1 {
            self.arguments.removeFirst(2)
        }
        #elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        // When tests are invoked directly through SwiftPM using `--filter`, SwiftPM will pass `-XCTest <filter>` to the
        // runner binary, and also the test bundle path unconditionally. These must be stripped for Vapor to be satisifed
        // with the validity of the arguments. We detect this case reliably the hard way, by looking for the `xctest`
        // runner executable and a leading argument with the `.xctest` bundle suffix.
        if self.executable.hasSuffix("/usr/bin/xctest") {
            if self.arguments.first?.lowercased() == "-xctest" && self.arguments.count > 1 {
                self.arguments.removeFirst(2)
            }
            if self.arguments.first?.hasSuffix(".xctest") ?? false {
                self.arguments.removeFirst()
            }
        }
        #endif
    }
}
