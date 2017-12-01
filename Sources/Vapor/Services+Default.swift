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
        services.register(Server.self) { context in
            return try EngineServer(
                config: context.make(for: EngineServer.self),
                context: context
            )
        }
        
        services.register { context in
            return EngineServerConfig()
        }

        // register middleware
        services.register { context -> MiddlewareConfig in
            var config = MiddlewareConfig()
            config.use(DateMiddleware.self)
            config.use(ErrorMiddleware.self)
            return config
        }
        
        services.register { context in
            return DateMiddleware()
        }
        
        services.register { context in
            return ErrorMiddleware(environment: context.environment)
        }

        // register router
        services.register([Router.self], isSingleton: true) { context in
            return TrieRouter()
        }

        // register content coders
        services.register { context in
            return ContentConfig.default()
        }

        // register terminal console
        services.register(Console.self) { context in
            return Terminal()
        }
        services.register { context -> ServeCommand in
            let router = try RouterResponder(
                router: context.make(for: ServeCommand.self)
            )

            let middleware = try context
                .make(MiddlewareConfig.self, for: ServeCommand.self)
                .resolve(for: context)

            return try ServeCommand(
                server: context.make(for: ServeCommand.self),
                responder: middleware.makeResponder(chainedto: router)
            )
        }
        services.register { context -> CommandConfig in
            return CommandConfig.default()
        }

        // worker
        services.register { context -> EphemeralWorkerConfig in
            let config = EphemeralWorkerConfig()
            config.add(Request.self)
            config.add(Response.self)
            return config
        }

        // directory
        services.register { context -> DirectoryConfig in
            return DirectoryConfig.default()
        }

        return services
    }
}
