extension Services {
    /// Vapor's default services. This includes many services required to successfully
    /// boot an Application. Only for special use cases should you create an empty `Services` struct.
    public static func `default`() -> Services {
        var s = Services()

        // server
        s.register(HTTPServerConfig.self) { c in
            return .init()
        }

        // client
        s.register(FoundationClient.self) { c in
            return FoundationClient(.shared, eventLoop: c.eventLoop)
        }

        // router
        s.register(EngineRouter.self) { c in
            return .init(caseInsensitive: false, eventLoop: c.eventLoop)
        }

        // responder
        s.register(HTTPResponder.self) { c in
            // initialize all `[Middleware]` from config
            let middleware = try c
                .make(MiddlewareConfig.self)
                .resolve()
            
            // create router and wrap in a responder
            let router = try c.make(Router.self)
            
            // return new responder
            return ApplicationResponder(router, middleware)
        }

        // bcrypt
        #warning("TODO: update BCryptDigest")
//        s.register { container -> BCryptDigest in
//            return .init()
//        }

        // sessions
        #warning("TODO: update sessions")
//        s.register(SessionsMiddleware.self)
//        s.register(KeyedCacheSessions.self)
//        s.register(MemorySessions(), as: Sessions.self)
        s.register(SessionsConfig.self) { c in
            return .default()
        }

        // keyed cache
        #warning("TODO: update keyed caches")
//        s.register(MemoryKeyedCache(), as: KeyedCache.self)

        // middleware
        s.register(MiddlewareConfig.self) { c in
            var middleware = MiddlewareConfig()
            try middleware.use(c.make(ErrorMiddleware.self))
            return middleware
        }
        s.register(FileMiddleware.self) { c in
            var workDir = try c.make(DirectoryConfig.self).workDir
            if !workDir.hasSuffix("/") {
                workDir.append("/")
            }
            return try .init(
                publicDirectory: workDir + "Public/",
                fileio: c.make()
            )
        }
        s.register(ErrorMiddleware.self) { c in
            return .default(environment: c.environment)
        }

        // content
//        s.register(ContentConfig.self)
//        s.register(ContentCoders.self)

        // console
        s.register(Console.self) { c in
            return Terminal(on: c.eventLoop)
        }
        

        // commands
        s.register(HTTPServeCommand.self) { c in
            return try .init(
                config: c.make(),
                console: c.make(),
                application: c.make()
            )
        }
        s.register(RoutesCommand.self) { c in
            return try .init(router: c.make())
        }
        s.register(BootCommand.self) { c in
            return .init()
        }
        s.register(CommandConfig.self) { c in
            var config = CommandConfig()
            try config.use(c.make(HTTPServeCommand.self), as: "serve", isDefault: true)
            try config.use(c.make(RoutesCommand.self), as: "routes")
            try config.use(c.make(BootCommand.self), as: "boot")
            return config
        }
        s.register(Commands.self) { c in
            return try c.make(CommandConfig.self).resolve()
        }

        // directory
        s.register(DirectoryConfig.self) { c in
            return .detect()
        }

        // logging
        #warning("TODO: update to sswg logging")
//        services.register(Logger.self) { container -> ConsoleLogger in
//            return try ConsoleLogger(console: container.make())
//        }
//        services.register(Logger.self) { container -> PrintLogger in
//            return PrintLogger()
//        }

        // templates
        #warning("TODO: update view renderer")
//        services.register(ViewRenderer.self) { container -> PlaintextRenderer in
//            let dir = try container.make(DirectoryConfig.self)
//            return PlaintextRenderer.init(viewsDir: dir.workDir + "Resources/Views/", on: container)
//        }

        // blocking IO pool is thread safe
        #warning("TODO: create blocking IO thread pool wrapper with auto shutdown")
        let sharedThreadPool = BlockingIOThreadPool(numberOfThreads: 2)
        sharedThreadPool.start()
        s.instance(sharedThreadPool)

        // file
        s.register(NonBlockingFileIO.self) { c in
            return try .init(threadPool: c.make())
        }
        s.register(FileIO.self) { c in
            #warning("TODO: re-use buffer allocator")
            return try .init(io: c.make(), allocator: .init(), on: c.eventLoop)
        }

        // websocket
        #warning("TODO: update websocket client")
        // services.register(NIOWebSocketClient.self)

        return s
    }
}
