import Console
import Command
import ServiceKit

/// Core framework class. You usually create only one of these per application. Acts as your application's top-level service container.
///
///     let router = try app.make(Router.self)
///
/// - note: When generating responses to requests, you should use the `Request` as your service-container.
///
/// Call the `run()` method to run this `Application`'s commands. By default, this will boot an `HTTPServer` and begin serving requests.
/// Which command is run depends on the command-line arguments and flags.
///
///     try app.run()
///
/// The `Application` is responsible for calling `Provider` (and `VaporProvider`) boot methods. The `willBoot` and `didBoot` methods
/// will be called on `Application.init(...)` for both provider types. `VaporProvider`'s will have their `willRun` and `didRun` methods
/// called on `Application.run()`
public final class Application {
    /// Environment this application is running in. Determines whether certain behaviors like verbose/debug logging are enabled.
    public var environment: Environment
    
    private let configure: () throws -> Services
    
    private let eventLoopGroup: EventLoopGroup

    /// Use this to create stored properties in extensions.
    public var userInfo: [AnyHashable: Any]
    
    public var runningServer: RunningServer?

    /// Creates and a new `Application`.
    ///
    /// - parameters:
    ///     - config: Configuration preferences for this service container.
    ///     - environment: Application's environment type (i.e., testing, production).
    ///                    Different environments can trigger different application behavior (for example, suppressing verbose logs in production mode).
    ///     - services: Application's available services. A copy of these services will be passed to all sub event-loops created by this Application.
    public init(
        _ environment: Environment = .development,
        _ configure: @escaping () throws -> Services
    ) throws {
        self.environment = environment
        self.configure = configure
        self.userInfo = [:]
        self.runningServer = nil
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 8)
        
        #warning("TODO: use logger")
        if _isDebugAssertConfiguration() && environment.isRelease {
            print("Debug build mode detected while configured for release environment: \(environment.name).")
            print("Compile your application with `-c release` to enable code optimizations.")
        }
    }
    
    public func makeContainer(on eventLoop: EventLoop) -> EventLoopFuture<Container> {
        do {
            var services = try self.configure()
            services.register(Application.self) { c in
                return self
            }
            let container = BasicContainer(environment: self.environment, services: services, on: eventLoop)
            #warning("TODO: make willBoot and didBoot non-throwing")
            let willBoots = container.providers.map { try! $0.willBoot(container) }
            return EventLoopFuture<Void>.andAll(willBoots, eventLoop: eventLoop).then { () -> EventLoopFuture<Void> in
                let didBoots = container.providers.map { try! $0.didBoot(container) }
                return .andAll(didBoots, eventLoop: eventLoop)
            }.map { _ in container }
        } catch {
            return eventLoop.makeFailedFuture(error: error)
        }
    }

    // MARK: Run

    /// Asynchronously runs the `Application`'s commands. This method will call the `willRun(_:)` methods of all
    /// registered `VaporProvider's` before running.
    ///
    /// Normally this command will boot an `HTTPServer`. However, depending on configuration and command-line arguments/flags, this method may run a different command.
    /// See `CommandConfig` for more information about customizing the commands that this method runs.
    ///
    ///     try app.run().wait()
    ///
    /// Note: When running a server, `asyncRun()` will return when the server has finished _booting_. Use the `runningServer` property on `Application` to wait
    /// for the server to close. The synchronous `run()` method will call this automatically.
    ///
    ///     try app.runningServer?.onClose().wait()
    ///
    /// All `VaporProvider`'s `didRun(_:)` methods will be called before finishing.
    public func run() -> EventLoopFuture<Void> {
        #warning("TODO: run VaporProvider willRuns")
        #warning("TODO: allow elg to be passed")
        return self.makeContainer(on: self.eventLoopGroup.next()).thenThrowing { c -> (Console, CommandGroup) in
            let command = try c.make(Commands.self).group()
            let console = try c.make(Console.self)
            return (console, command)
        }.then { res -> EventLoopFuture<Void> in
            var runInput = self.environment.commandInput
            return res.0.run(res.1, input: &runInput)
        }
//        // will-run all vapor service providers
//        return try self.providers.onlyVapor.map { try $0.willRun(self) }.flatten(on: self)
//        // did-run all vapor service providers
//        return try self.providers.onlyVapor.map { try $0.didRun(self) }.flatten(on: self)
    }
    
    deinit {
        try! self.eventLoopGroup.syncShutdownGracefully()
    }
}

// MARK: Environment

#warning("TODO: move this to separate file")

extension Environment {
    /// Exposes the `Environment`'s `arguments` property as a `CommandInput`.
    public var commandInput: CommandInput {
        get { return CommandInput(arguments: arguments) }
        set { arguments = newValue.executablePath + newValue.arguments }
    }

    /// Detects the environment from `CommandLine.arguments`. Invokes `detect(from:)`.
    /// - parameters:
    ///     - arguments: Command line arguments to detect environment from.
    /// - returns: The detected environment, or default env.
    public static func detect(arguments: [String] = CommandLine.arguments) throws -> Environment {
        var commandInput = CommandInput(arguments: arguments)
        return try Environment.detect(from: &commandInput)
    }

    /// Detects the environment from `CommandInput`. Parses the `--env` flag.
    /// - parameters:
    ///     - arguments: `CommandInput` to parse `--env` flag from.
    /// - returns: The detected environment, or default env.
    public static func detect(from commandInput: inout CommandInput) throws -> Environment {
        var env: Environment
        if let value = try commandInput.parse(option: .value(name: "env", short: "e")) {
            switch value {
            case "prod", "production": env = .production
            case "dev", "development": env = .development
            case "test", "testing": env = .testing
            default: env = .init(name: value, isRelease: false)
            }
        } else {
            env = .development
        }
        env.commandInput = commandInput
        return env
    }
}


