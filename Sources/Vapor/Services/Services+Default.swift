import Crypto

extension Services {
    /// Vapor's default services. This includes many services required to successfully
    /// boot an Application. Only for special use cases should you create an empty `Services` struct.
    public static func `default`() -> Services {
        var services = Services()

        // server
        services.register(NIOServer.self)
        services.register(NIOServerConfig.self)
        services.register(RunningServerCache.self)

        // client
        services.register(FoundationClient.self)

        // router
        services.register(EngineRouter.default(), as: Router.self)

        // responder
        services.register(ApplicationResponder.self)

        // bcrypt
        services.register { container -> BCryptDigest in
            return .init()
        }

        // sessions
        services.register(SessionCache.self)
        services.register(SessionsMiddleware.self)
        services.register(KeyedCacheSessions.self)
        services.register(MemorySessions(), as: Sessions.self)
        services.register(SessionsConfig.self)

        // keyed cache
        services.register(MemoryKeyedCache(), as: KeyedCache.self)

        // middleware
        services.register(MiddlewareConfig.self)
        services.register(FileMiddleware.self)
        services.register(ErrorMiddleware.self)

        // content
        services.register(ContentConfig.self)
        services.register(ContentCoders.self)

        // console
        services.register(Console.self) { container -> Terminal in
            return Terminal()
        }

        // commands
        services.register(BootCommand.self)
        services.register(ServeCommand.self)
        services.register(RoutesCommand.self)
        services.register { container -> CommandConfig in
            return .default()
        }
        services.register { container -> Commands in
            return try container.make(CommandConfig.self).resolve(for: container)
        }

        // directory
        services.register { container -> DirectoryConfig in
            return DirectoryConfig.detect()
        }

        // logging
        services.register(Logger.self) { container -> ConsoleLogger in
            return try ConsoleLogger(console: container.make())
        }
        services.register(Logger.self) { container -> PrintLogger in
            return PrintLogger()
        }

        // templates
        services.register(ViewRenderer.self) { container -> PlaintextRenderer in
            let dir = try container.make(DirectoryConfig.self)
            return PlaintextRenderer.init(viewsDir: dir.workDir + "Resources/Views/", on: container)
        }

        // blocking IO pool is thread safe
        let sharedThreadPool = BlockingIOThreadPool(numberOfThreads: 2)
        sharedThreadPool.start()
        services.register(sharedThreadPool)

        // file
        services.register(NonBlockingFileIO.self)

        // websocket
        services.register(NIOWebSocketClient.self)

        return services
    }
}

extension PlaintextRenderer: Service { }
extension Terminal: Service { }
extension DirectoryConfig: Service { }
extension ConsoleLogger: Service { }
extension PrintLogger: Service { }
extension BCryptDigest: Service { }
