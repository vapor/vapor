import Async
import Command
import Console
import Dispatch
import Foundation
import HTTP
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

    /// See Worker.queue
    public let eventLoop: EventLoop

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
        self.eventLoop = try DefaultEventLoop(label: "codes.vapor.application")

        Thread.async {
            self.eventLoop.runLoop()
        }

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
        exit(0)
    }
}
