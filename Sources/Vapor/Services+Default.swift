import HTTP
import Routing
import Service

extension Services {
    /// The default Services included in the framework.
    public static func `default`() -> Services {
        var services = Services()

        // register engine server and default config settings
        services.register(Server.self) { container in
            return try EngineServer(
                config: container.make(for: EngineServer.self)
            )
        }
        services.register { container in
            return EngineServerConfig()
        }

        // register middleware
        services.register { container in
            return MiddlewareConfig([
                DateMiddleware.self
            ])
        }
        services.register(Middleware.self) { container in
            return DateMiddleware()
        }

        // register router
        services.register([SyncRouter.self, AsyncRouter.self, Router.self]) { container in
            return TestRouter()
        }

        return services
    }
}
