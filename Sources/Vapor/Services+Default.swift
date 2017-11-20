import Async
import Console
import HTTP
import Foundation
import Routing
import Service

extension Services {
    /// The default Services included in the framework.
    public static func `default`() -> Services {
        var services = Services()

        // register engine server and default config settings
        services.register(HTTPServer.self) { container in
            return try EngineServer(
                config: container.make(for: EngineServer.self),
                container: container
            )
        }
        services.register { container in
            return EngineServerConfig()
        }

        // register middleware
        services.register { container -> MiddlewareConfig in
            var config = MiddlewareConfig()
            config.use(DateMiddleware.self)
            config.use(ErrorMiddleware.self)
            return config
        }
        
        services.register { container in
            return DateMiddleware()
        }
        
        services.register { container in
            return ErrorMiddleware(environment: container.environment)
        }

        // register router
        services.register([Router.self]) { container in
            return TrieRouter()
        }

        // register content coders
        services.register { container in
            return ContentConfig.default()
        }

        // register terminal console
        services.register(Console.self) { container in
            return Terminal()
        }

        services.register { container -> ServeCommand in
            let router = try RouterResponder(
                router: container.make(for: ServeCommand.self)
            )

            let middleware = try container
                .make(MiddlewareConfig.self, for: ServeCommand.self)
                .resolve(for: container)

            return try ServeCommand(
                server: container.make(for: ServeCommand.self),
                responder: middleware.makeResponder(chainedto: router)
            )
        }

        services.register { container -> CommandConfig in
            return CommandConfig.default()
        }

        return services
    }
}

extension Application: Worker, HasContainer {
    public var container: Container? {
        return self
    }

    public var eventLoop: EventLoop {
        return EventLoop.default
    }
}


