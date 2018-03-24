/// Core framework class. You usually create only one of these per application. Acts as your application's top-level service container.
///
///     let router = try app.make(Router.self)
///
/// Note: When generating responses to requests, you should use the `Request` as your service-container.
///
/// Call the `run()` method to run this `Application`'s commands. By default, this will boot an `HTTPServer` and begin serving requests.
/// Which command is run depends on the command-line arguments and flags.
///
///     try app.run()
///
/// The `Application` is responsible for calling `Provider` (and `VaporProvider`) boot methods. The `willBoot` and `didBoot` methods
/// will be called on `Application.init(_:)` for both provider types. `VaporProvider`'s will have their `willRun` and `didRun` methods
/// called on `Application.run()`
///
/// https://docs.vapor.codes/3.0/getting-started/application/
public final class Application: Container {
    /// Config preferences and requirements for available services. Used to disambiguate which service should be used
    /// for a given interface when multiple are available.
    /// See `Config` for more information.
    public let config: Config

    /// Environment this application is running in. Determines whether certain behaviors like verbose/debug logging are enabled.
    /// See `Environment` for more information.
    public let environment: Environment

    /// Services that can be created by this application. A copy of these services will be passed to all sub-containers created
    /// form this application (i.e., `Request`, `Response`, etc.)
    /// See `Services` for more information.
    public let services: Services

    /// The `Application`'s private service cache. This cache will not be shared with any sub-containers created by this application.
    public let serviceCache: ServiceCache

    /// The event loop group that we derive the event loop below from, so we can close it in `deinit`.
    private var eventLoopGroup: EventLoopGroup

    /// This `Application`'s event loop. This event-loop is separate from the `HTTPServer`'s event loop group and should only be used
    /// for creating services during boot / configuration phases. Never use this event loop while responding to requests.
    public var eventLoop: EventLoop { return eventLoopGroup.next() }

    /// Use this to create stored properties in extensions.
    public var extend: Extend

    /// Creates a new `Application`.
    ///
    /// - parameters:
    ///     - config: Configuration preferences for this service container.
    ///     - environment: Application's environment type (i.e., testing, production).
    ///                    Different environments can trigger different application behavior (for example, supressing verbose logs in production mode).
    ///     - services: Application's available services. A copy of these services will be passed to all sub event-loops created by this Application.
    public init(
        config: Config = .default(),
        environment: Environment = .development,
        services: Services = .default()
    ) throws {
        self.config = config
        self.environment = environment
        self.services = services
        self.serviceCache = .init()
        self.extend = Extend()
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numThreads: 1)

        // will-boot all service providers
        for provider in services.providers {
            try provider.willBoot(self).wait()
        }

        if _isDebugAssertConfiguration() && environment.isRelease {
            let log = try self.make(Logger.self)
            log.warning("Debug build mode detected while configured for release environment: \(environment.name).")
            log.info("Compile your application with `-c release` to enable code optimizations.")
        }

        // did-boot all service providers
        for provider in services.providers {
            try provider.didBoot(self).wait()
        }
    }

    /// Runs the `Application`'s commands. This method will call the `willRun(_:)` methods of all registered `VaporProvider's` before running.
    ///
    /// Normally this command will boot an `HTTPServer` that will run indefinitely. However, depending on configuration and command-line arguments/flags, this method may run a different command.
    /// To prevent confusion, this method will call `exit` before finishing and returns `Never`.
    ///
    /// See `CommandConfig` for more information about customizing the commands that this method runs.
    ///
    /// All `VaporProvider`'s `didRun(_:)` methods will be called before the `Application` calls `exit`.
    public func run() throws -> Never {
        // will-run all vapor service providers
        for provider in services.providers.onlyVapor {
            try provider.willRun(self).wait()
        }

        let command = try make(CommandConfig.self)
            .makeCommandGroup(for: self)

        let console = try make(Console.self)
        try console.run(command, input: &.commandLine)

        // did-run all vapor service providers
        for provider in services.providers.onlyVapor {
            try provider.didRun(self).wait()
        }
        
        // Enforce `Never` return.
        // It's possible that this method may actually return, since
        // not all Vapor commands have run loops.
        // However, because this method likely _can_ result in
        // a run loop, having a `Never` may help reduce bugs.
        exit(0)
    }

    deinit {
        eventLoopGroup.shutdownGracefully {
            if let error = $0 {
                ERROR("shutting down app event loop: \(error)")
            }
        }
    }
}
