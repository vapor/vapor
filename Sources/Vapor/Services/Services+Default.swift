import Async
import Console
import Dispatch
import HTTP
import Foundation
import Routing
import Service
import TLS
#if os(Linux)
    import OpenSSL
#else
    import AppleTLS
#endif

extension Services {
    /// The default Services included in the framework.
    public static func `default`() -> Services {
        var services = Services()

        // register engine server and default config settings
        services.register(Server.self) { container -> EngineServer in
            return try EngineServer(
                config: container.make(for: EngineServer.self),
                container: container
            )
        }
        
        services.register { container -> EngineServerConfig in
            if container.environment.isRelease {
                return try EngineServerConfig.detect(port: 80)
            } else {
                return try EngineServerConfig.detect()
            }
        }

        // bcrypt
        services.register { container -> BCryptHasher in
            let cost: UInt

            switch container.environment {
            case .production: cost = 12
            default: cost = 4
            }
            
            return BCryptHasher(
                version: .two(.y),
                cost: cost
            )
        }

        // sessions
        services.register(SessionCache.self)
        services.register(SessionsMiddleware.self)
        services.register(KeyedCacheSessions.self)
        services.register(SessionsConfig.self)

        // keyed cache
        services.register(KeyedCache.self) { container -> MemoryKeyedCache in
            return MemoryKeyedCache()
        }
        
//        services.register { container in
//            return SSLClientSettings()
//        }
//        
//        services.register(SSLClientUpgrader.self) { _ in
//            return DefaultSSLClientUpgrader()
//        }
//        
//        services.register(SSLPeerUpgrader.self) { _ in
//            return DefaultSSLPeerUpgrader()
//        }
//        
//        services.register(SSLClient.self) { container -> DefaultSSLClient in
//            let client = try defaultSSLClient.init(
//                settings: try container.make(for: SSLClientSettings.self),
//                on: container
//            )
//            
//            return BasicSSLClient(boxing: client)
//        }

        services.register(Client.self) { container -> EngineClient in
            if let sub = container as? SubContainer {
                /// if a request is creating a client, we should
                /// use the event loop as the container
                return try EngineClient(container: sub.superContainer, config: container.make(for: EngineClient.self))
            } else {
                return try EngineClient(container: container, config: container.make(for: EngineClient.self))
            }
        }

        services.register { container -> EngineClientConfig in
            return EngineClientConfig()
        }

        // register middleware
        services.register { container -> MiddlewareConfig in
            return MiddlewareConfig.default()
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
        services.register(Router.self) { container -> EngineRouter in
            return EngineRouter.default()
        }

        // register content coders
        services.register(ContentConfig.self)
        services.register(ContentCoders.self)
        
        // register transfer encodings
        services.register { container -> TransferEncodingConfig in
            return TransferEncodingConfig.default()
        }

        services.register([FileReader.self, FileCache.self]) { container -> File in
            return File(on: container)
        }

        // register terminal console
        services.register(Console.self) { container -> Terminal in
            return Terminal()
        }
        services.register(Responder.self) { container -> ApplicationResponder in
            let middleware = try container
                .make(MiddlewareConfig.self, for: ServeCommand.self)
                .resolve(for: container)

            let router = try RouterResponder(
                router: container.make(for: Responder.self)
            )
            let wrapped = middleware.makeResponder(chainedto: router)
            return ApplicationResponder(wrapped)
        }

        services.register { worker -> ServeCommand in
            return try ServeCommand(
                server: worker.make(for: ServeCommand.self)
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

        // directory
        services.register { container -> DirectoryConfig in
            return DirectoryConfig.detect()
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

        // templates
        services.register(TemplateRenderer.self) { container -> PlaintextRenderer in
            let dir = try container.make(DirectoryConfig.self, for: PlaintextRenderer.self)
            return PlaintextRenderer.init(viewsDir: dir.workDir + "Resources/Views/", on: container)
        }

        // multipart
        services.register(MultipartFormConfig.self)

        return services
    }
}

public struct ApplicationResponder: Responder, Service {
    private let responder: Responder
    init(_ responder: Responder) {
        self.responder = responder
    }

    public func respond(to req: Request) throws -> Future<Response> {
        return try responder.respond(to: req);
        
        let promise = Promise(Response.self)
        // attempt to respond before, so thrown errors prevent timer creation
        try responder.respond(to: req).chain(to: promise)
        // add a global timeout
        var timer: EventSource?
        timer = req.eventLoop.onTimeout(timeout: .seconds(30)) { eof in
            let error = VaporError(
                identifier: "timeout",
                reason: "The application timed out waiting for response.",
                suggestedFixes: [
                    "Inspect the route responsible for responding to \(req.http.method) \(req.http.uri.path)"
                ],
                source: .capture()
            )
            promise.fail(error)
            timer?.cancel()
        }
        timer?.resume()
        return promise.future
    }
}

extension PlaintextRenderer: Service {}
extension File: Service { }
extension Terminal: Service { }
extension EphemeralWorkerConfig: Service { }
extension DirectoryConfig: Service { }
extension ConsoleLogger: Service { }
extension PrintLogger: Service {}
extension MemoryKeyedCache: Service {}
