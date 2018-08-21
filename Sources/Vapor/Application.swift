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
public final class Application: Container {
    /// Config preferences and requirements for available services. Used to disambiguate which service should be used
    /// for a given interface when multiple are available.
    public let config: Config

    /// Environment this application is running in. Determines whether certain behaviors like verbose/debug logging are enabled.
    public var environment: Environment

    /// Services that can be created by this application. A copy of these services will be passed to all sub-containers created
    /// form this application (i.e., `Request`, `Response`, etc.)
    public let services: Services

    /// The `Application`'s private service cache. This cache will not be shared with any sub-containers created by this application.
    public let serviceCache: ServiceCache

    /// The `EventLoopGroup` that we derive the event loop below from, so we can close it in `deinit`.
    private var eventLoopGroup: EventLoopGroup

    /// This `Application`'s event loop. This event-loop is separate from the `HTTPServer`'s event loop group and should only be used
    /// for creating services during boot / configuration phases. Never use this event loop while responding to requests.
    public var eventLoop: EventLoop {
        return eventLoopGroup.next()
    }

    /// Use this to create stored properties in extensions.
    public var extend: Extend

    // MARK: Boot

    /// Asynchronously creates and boots a new `Application`.
    ///
    /// - parameters:
    ///     - config: Configuration preferences for this service container.
    ///     - environment: Application's environment type (i.e., testing, production).
    ///                    Different environments can trigger different application behavior (for example, supressing verbose logs in production mode).
    ///     - services: Application's available services. A copy of these services will be passed to all sub event-loops created by this Application.
    public static func asyncBoot(config: Config = .default(), environment: Environment = .development, services: Services = .default()) -> Future<Application> {
        let app = Application(config, environment, services)
        return app.boot().transform(to: app)
    }

    /// Synchronously creates and boots a new `Application`.
    ///
    /// - parameters:
    ///     - config: Configuration preferences for this service container.
    ///     - environment: Application's environment type (i.e., testing, production).
    ///                    Different environments can trigger different application behavior (for example, suppressing verbose logs in production mode).
    ///     - services: Application's available services. A copy of these services will be passed to all sub event-loops created by this Application.
    public convenience init(
        config: Config = .default(),
        environment: Environment = .development,
        services: Services = .default()
    ) throws {
        self.init(config, environment, services)
        try boot().wait()
    }

    // MARK: Run

    /// Asynchronously runs the `Application`'s commands. This method will call the `willRun(_:)` methods of all
    /// registered `VaporProvider's` before running.
    ///
    /// Normally this command will boot an `HTTPServer`. However, depending on configuration and command-line arguments/flags, this method may run a different command.
    /// See `CommandConfig` for more information about customizing the commands that this method runs.
    ///
    ///     try app.asyncRun().wait()
    ///
    /// Note: When running a server, `asyncRun()` will return when the server has finished _booting_. Use the `runningServer` property on `Application` to wait
    /// for the server to close. The synchronous `run()` method will call this automatically.
    ///
    ///     try app.runningServer?.onClose().wait()
    ///
    /// All `VaporProvider`'s `didRun(_:)` methods will be called before finishing.
    public func asyncRun() -> Future<Void> {
        return Future.flatMap(on: self) {
            // will-run all vapor service providers
            return try self.providers.onlyVapor.map { try $0.willRun(self) }.flatten(on: self)
        }.flatMap {
            let command = try self.make(Commands.self)
                .group()
            let console = try self.make(Console.self)

            /// Create a mutable copy of the environment input for this run.
            var runInput = self.environment.commandInput
            return console.run(command, input: &runInput, on: self)
        }.flatMap {
            // did-run all vapor service providers
            return try self.providers.onlyVapor.map { try $0.didRun(self) }.flatten(on: self)
        }
    }

    /// Synchronously calls `asyncRun()` and waits for the running server to close (if one exists).
    public func run() throws {
        try asyncRun().wait()
        try runningServer?.onClose.wait()
    }

    // MARK: Internal

    /// Internal initializer. Creates an `Application` without booting providers.
    internal init(_ config: Config, _ environment: Environment, _ services: Services) {
        self.config = config
        self.environment = environment
        self.services = services
        self.serviceCache = .init()
        self.extend = Extend()
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    /// Internal method. Boots the application and its providers.
    internal func boot() -> Future<Void> {
        return Future.flatMap(on: self) {
            // will-boot all service providers
            return try self.providers.map { try $0.willBoot(self) }.flatten(on: self)
        }.map {
            if _isDebugAssertConfiguration() && self.environment.isRelease {
                let log = try self.make(Logger.self)
                log.warning("Debug build mode detected while configured for release environment: \(self.environment.name).")
                log.info("Compile your application with `-c release` to enable code optimizations.")
            }
        }.flatMap {
            // did-boot all service providers
            return try self.providers.map { try $0.didBoot(self) }.flatten(on: self)
        }
    }

    /// Called when the app deinitializes.
    deinit {
        eventLoopGroup.shutdownGracefully {
            if let error = $0 {
                ERROR("shutting down app event loop: \(error)")
            }
        }
    }
}
