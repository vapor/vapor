import Async
import Dispatch
import Foundation
import HTTP
import Routing
import Service

/// Core framework class. You usually create only
/// one of these per application.
/// Acts as a service container and much more.
public final class Application: Container {
    /// Config preferences and requirements for available services.
    public var config: Config

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
    ) {
        self.config = config
        self.environment = environment
        self.services = services
        self.extend = Extend()
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

        let middleware = try make(MiddlewareConfig.self).resolve(for: self)
        let chained = middleware.makeResponder(chainedto: router)
        try server.start(with: chained)

        let group = DispatchGroup()
        group.enter()
        group.wait()
        exit(0)
    }
}
