import Async
import Dispatch
import Foundation
import HTTP
import Routing
import Service

/// Core framework class. You usually create only
/// one of these per application.
/// Acts as a service container and much more.
///
/// [Learn More →](https://docs.vapor.codes/3.0/vapor/application/#creating-a-basic-application)
public final class Application: Container {
    /// Config preferences and requirements for available services.
    public let config: Config

    /// Environment this application is running in.
    public let environment: Environment

    /// Services that can be created by this application.
    public let services: Services

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
        self.extend = Extend()

        // boot all service providers
        for provider in services.providers {
            try provider.boot(self)
        }
    }

    /// Make an instance of the provided interface for this Application.
    public func make<T>(_ interface: T.Type) throws -> T {
        return try make(T.self, for: Application.self)
    }

    /// Runs the Application's server.
    public func run() throws -> Never {
        // TODO: run console / commands here.
        let server = try make(HTTPServer.self)

        let router = try RouterResponder(
            router: make(Router.self)
        )

        let middleware = try defaultMiddleware() + make(MiddlewareConfig.self).resolve(for: self)
        let chained = middleware.makeResponder(chainedto: router)
        try server.start(with: chained)

        let group = DispatchGroup()
        group.enter()
        group.wait()
        exit(0)
    }

    // MARK: Private

    /// creates an array of default middleware the application
    /// needs to work properly
    func defaultMiddleware() -> [Middleware] {
        return [ApplicationMiddleware(application: self)]
    }
}
