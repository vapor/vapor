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
    private var eventLoopGroup: EventLoopGroup

    /// See Worker.eventLoop
    public var eventLoop: EventLoop { return eventLoopGroup.next() }

    /// Use this to create stored properties in extensions.
    public var extend: Extend

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
    
    deinit {
        eventLoopGroup.shutdownGracefully {
            if let error = $0 {
                ERROR("shutting down app event loop: \(error)")
            }
        }
    }

    /// Runs the Application's commands.
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
}
