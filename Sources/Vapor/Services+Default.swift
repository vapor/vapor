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
                config: container.make(for: EngineServer.self)
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

            var middleware: [Middleware] = [
                ContainerMiddleware(container: container)
            ]
            middleware += try container
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

extension Request: HasContainer { }
extension Response: HasContainer { }

extension Message {
    public var container: Container? {
        return eventLoop.container
    }
}

extension EventLoop: HasContainer {
    public var container: Container? {
        get { return extend["vapor:container"] as? Container }
        set { extend["vapor:container"] = newValue }
    }
}

import Async

// FIXME: set event loop container on init?
internal class ContainerMiddleware: Middleware {
    let container: Container

    init(container: Container) {
        self.container = container
    }

    func respond(
        to req: Request,
        chainingTo next: Responder
    ) throws -> Future<Response> {
        req.eventLoop.container = self.container
        return try next.respond(to: req)
    }
}
