import HTTP
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

        // register responder
        services.register(Responder.self) { container in
            return try RouterResponder(
                router: container.make(for: RouterResponder.self)
            )
        }

        // register router
        services.register(Router.self) { container in
            return TestRouter()
        }

        return services
    }
}
