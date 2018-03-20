import Async
import Command
import Console
import Dispatch
import Foundation
import Routing
import Service

/// Core framework class. You usually create only
/// one of these per application.
/// Acts as a service container and much more.
///
/// [Learn More →](https://docs.vapor.codes/3.0/getting-started/application/)
public final class Application: Container {
    /// Config preferences and requirements for available services.
    public let config: Config

    /// Environment this application is running in.
    public let environment: Environment

    /// Services that can be created by this application.
    public let services: Services

    /// See ServiceCacheable.serviceCache
    public let serviceCache: ServiceCache

    /// The event loop group that we derive the event loop below from, so we can close it in `deinit`
    private var eventLoopGroup: EventLoopGroup = MultiThreadedEventLoopGroup(numThreads: 1)

    /// See Worker.eventLoop
    public var eventLoop: EventLoop

    /// Use this to create stored properties in extensions.
    public var extend: Extend
    
    /// An internal reference to the Router to provide routing shortcuts
    ///
    /// FIXME: Force unwrapped because you cannot initialize a router before the rest is initialized
    fileprivate var router: Router!

    /// Creates a new Application.
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
        self.eventLoop = eventLoopGroup.next()
        self.router = try self.make(Router.self, for: Application.self)

        // boot all service providers
        for provider in services.providers {
            try provider.boot(self)
        }

        if _isDebugAssertConfiguration() && environment.isRelease {
            let log = try self.make(Logger.self)
            log.warning("Debug build mode detected while configured for release environment: \(environment.name).")
            log.info("Compile your application with `-c release` to enable code optimizations.")
        }
    }
    
    deinit {
        eventLoopGroup.shutdownGracefully {
            if let error = $0 {
                print("[Vapor] shutting down app event loop: \(error)")
            }
        }
    }

    /// Make an instance of the provided interface for this Application.
    public func make<T>(_ interface: T.Type) throws -> T {
        return try make(T.self, for: Application.self)
    }

    /// Runs the Application's commands.
    public func run() throws -> Never {
        let command = try make(CommandConfig.self)
            .makeCommandGroup(for: self)

        let console = try make(Console.self)
        try console.run(command, input: &.commandLine)
        
        // Enforce `Never` return.
        // It's possible that this method may actually return, since
        // not all Vapor commands have run loops.
        // However, because this method likely _can_ result in
        // a run loop, having a `Never` may help reduce bugs.
        exit(0)
    }
}

extension Application: Router {
    /// All routes registered to this router
    public var routes: [Route<Responder>] {
        return router.routes
    }
    
    /// Routes a new Request to get a responder that can make a Response
    public func route(request: Request) -> Responder? {
        return router.route(request: request)
    }
    
    /// Registers a new route. This should only be done during boot
    public func register(route: Route<Responder>) {
        router.register(route: route)
    }
}
