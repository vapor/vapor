import Async
import Console
import Dispatch
import HTTP
import Foundation
import Routing
import Service
import TLS

extension Services {
    /// The default Services included in the framework.
    public static func `default`() -> Services {
        var services = Services()

        // register engine server and default config settings
        services.register(Server.self) { container in
            return try EngineServer(
                config: container.make(for: EngineServer.self),
                container: container
            )
        }
        
        services.register { container in
            return EngineServerConfig()
        }
        
        services.register(Client.self) { container -> EngineClient in
            if let sub = container as? SubContainer {
                /// if a request is creating a client, we should
                /// use the event loop as the container
                return try EngineClient(container: sub.superContainer, config: container.make(for: EngineClient.self))
            } else {
                return try EngineClient(container: container, config: container.make(for: EngineClient.self))
            }
        }

        services.register { container in
            return EngineClientConfig(maxResponseSize: 10_000_000)
        }

        // register middleware
        services.register { container -> MiddlewareConfig in
            var config = MiddlewareConfig()
            config.use(FileMiddleware.self)
            config.use(DateMiddleware.self)
            config.use(ErrorMiddleware.self)
            return config
        }

        services.register { container -> FileMiddleware in
            let directory = try container.make(DirectoryConfig.self, for: FileMiddleware.self)
            return FileMiddleware(publicDirectory: directory.workDir + "Public/")
        }
        
        services.register { container in
            return DateMiddleware()
        }
        
        services.register { worker in
            return try ErrorMiddleware(environment: worker.environment, log: worker.make(for: ErrorMiddleware.self))
        }

        // register router
        services.register(Router.self, isSingleton: true) { container in
            return EngineRouter.default()
        }

        // register content coders
        services.register { container in
            return ContentConfig.default()
        }
        
        // register transfer encodings
        services.register { container in
            return TransferEncodingConfig.default()
        }

        services.register([FileReader.self, FileCache.self]) { container in
            return File(on: container)
        }

        // register terminal console
        services.register(Console.self) { container in
            return Terminal()
        }
        services.register(Responder.self) { container in
            return try RouterResponder(
                router: container.make(for: Responder.self)
            )
        }

        services.register { worker -> ServeCommand in
            let responder = try worker.make(Responder.self, for: ServeCommand.self)

            let middleware = try worker
                .make(MiddlewareConfig.self, for: ServeCommand.self)
                .resolve(for: worker)

            return try ServeCommand(
                server: worker.make(for: ServeCommand.self),
                responder: middleware.makeResponder(chainedto: responder)
            )
        }
        services.register { container -> CommandConfig in
            return CommandConfig.default()
        }
        services.register { container -> RoutesCommand in
            return try RoutesCommand(
                router: container.make(for: RoutesCommand.self)
            )
        }

        // worker
        services.register { container -> EphemeralWorkerConfig in
            let config = EphemeralWorkerConfig()
            config.add(Request.self)
            config.add(Response.self)
            return config
        }

        // directory
        services.register { container -> DirectoryConfig in
            return DirectoryConfig.default()
        }

        // logging
        services.register(Logger.self) { container -> ConsoleLogger in
            return try ConsoleLogger(
                console: container.make(for: ConsoleLogger.self)
            )
        }
        services.register(Logger.self) { container -> PrintLogger in
            return PrintLogger()
        }

        return services
    }
}
