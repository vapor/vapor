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
    public var app: Application? {
        get { return extend["vapor:application"] as? Application }
        set { extend["vapor:application"] = newValue }
    }

    public var container: Container? {
        return app
    }
}

import Async

internal class ApplicationMiddleware: Middleware {
    let application: Application

    init(application: Application) {
        self.application = application
    }

    func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        req.app = application
        return try next.respond(to: req)
    }
}
