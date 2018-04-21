import Async
import CacheKit
import Console
import Crypto
import Dispatch
import Foundation
import Routing
import Service

extension Services {
    /// The default Services included in the framework.
    public static func `default`() -> Services {
        var services = Services()

        // register engine server and default config settings
        services.register(Server.self) { container -> EngineServer in
            return try EngineServer(
                config: container.make(),
                container: container
            )
        }

        // register defualt `EngineServerConfig`
        services.register { container -> EngineServerConfig in
            return .default()
        }

        // bcrypt
        services.register { container -> BCryptDigest in
            return .init()
        }

        // sessions
        services.register(SessionCache.self)
        services.register(SessionsMiddleware.self)
        services.register(KeyedCacheSessions.self)
        services.register(SessionsConfig.self)

        services.register(RunningServerCache())

        // keyed cache, memory. thread-safe
        let memoryKeyedCache = MemoryKeyedCache()
        services.register(memoryKeyedCache, as: KeyedCache.self)

        services.register(FoundationClient.self)

        // register middleware
        services.register { container -> MiddlewareConfig in
            return MiddlewareConfig.default()
        }

        services.register { container -> FileMiddleware in
            let directory = try container.make(DirectoryConfig.self)
            return FileMiddleware(publicDirectory: directory.workDir + "Public/")
        }

        services.register { container in
            return DateMiddleware()
        }
        
        services.register { worker in
            return try ErrorMiddleware(environment: worker.environment, log: worker.make())
        }

        // register router
        services.register(EngineRouter.default(), as: Router.self)

        // register content coders
        services.register(ContentConfig.self)
        services.register(ContentCoders.self)


        // register terminal console
        services.register(Console.self) { container -> Terminal in
            return Terminal()
        }
        services.register(Responder.self) { container -> ApplicationResponder in
            let middleware = try container
                .make(MiddlewareConfig.self)
                .resolve(for: container)

            let router = try RouterResponder(
                router: container.make()
            )
            let wrapped = middleware.makeResponder(chainedto: router)
            return ApplicationResponder(wrapped)
        }

        services.register { worker -> ServeCommand in
            return try ServeCommand(
                server: worker.make()
            )
        }
        services.register { container -> CommandConfig in
            return CommandConfig.default()
        }
        services.register { container -> Commands in
            return try container.make(CommandConfig.self).resolve(for: container)
        }

        services.register { container -> RoutesCommand in
            return try RoutesCommand(
                router: container.make()
            )
        }

        // directory
        services.register { container -> DirectoryConfig in
            return DirectoryConfig.detect()
        }

        // logging
        services.register(Logger.self) { container -> ConsoleLogger in
            return try ConsoleLogger(
                console: container.make()
            )
        }
        services.register(Logger.self) { container -> PrintLogger in
            return PrintLogger()
        }

        // templates
        services.register(TemplateRenderer.self) { container -> PlaintextRenderer in
            let dir = try container.make(DirectoryConfig.self)
            return PlaintextRenderer.init(viewsDir: dir.workDir + "Resources/Views/", on: container)
        }

        return services
    }
}

public struct ApplicationResponder: Responder, Service {
    private let responder: Responder
    init(_ responder: Responder) {
        self.responder = responder
    }

    public func respond(to req: Request) throws -> Future<Response> {
        return try responder.respond(to: req)
    }
}

extension PlaintextRenderer: Service { }
extension Terminal: Service { }
extension DirectoryConfig: Service { }
extension ConsoleLogger: Service { }
extension PrintLogger: Service {}
extension MemoryKeyedCache: Service {}
extension BCryptDigest: Service { }
