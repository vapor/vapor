extension Services {
    /// Vapor's default services. This includes many services required to successfully
    /// boot an Application. Only for special use cases should you create an empty `Services` struct.
    public static func `default`() -> Services {
        var s = Services()

        // auth
        s.register(PasswordVerifier.self) { c in
            return BCryptDigest()
        }
        s.register(PlaintextVerifier.self) { c in
            return PlaintextVerifier()
        }
        s.register(PasswordVerifier.self) { c in
            return try c.make(PlaintextVerifier.self)
        }
        
        // client
        s.register(URLSessionConfiguration.self) { c in
            return .default
        }
        s.register(URLSession.self) { c in
            return try .init(configuration: c.make())
        }
        s.register(FoundationClient.self) { c in
            return try .init(c.make(), on: c.eventLoop)
        }
        s.register(HTTPClient.Configuration.self) { c in
            return .init()
        }
        s.register(HTTPClient.self) { c in
            return try .init(
                eventLoopGroupProvider: .shared(c.eventLoop),
                configuration: c.make()
            )
        }
        s.register(Client.self) { c in
            return try c.make(HTTPClient.self)
        }
        
        // routes
        s.register(Routes.self) { c in
            return .init(eventLoop: c.eventLoop)
        }
        
        // sessions
        s.register(SessionsMiddleware.self) { c in
            return try .init(sessions: c.make(), config: c.make())
        }
        s.register(Sessions.self) { c in
            return try c.make(MemorySessions.self)
        }
        s.register(MemorySessions.self) { c in
            return try MemorySessions(storage: c.make(), on: c.eventLoop)
        }
        s.register(MemorySessions.Storage.self) { c in
            let app = try c.make(Application.self)
            app.lock.lock()
            defer { app.lock.unlock() }
            let key = "memory-sessions-storage"
            if let existing = app.userInfo[key] as? MemorySessions.Storage {
                return existing
            } else {
                let new = MemorySessions.Storage()
                app.userInfo[key] = new
                return new
            }
        }
        
        s.register(SessionsConfig.self) { c in
            return .default()
        }

        // keyed cache
        #warning("TODO: update keyed caches")
//        s.register(MemoryKeyedCache(), as: KeyedCache.self)

        // middleware
        s.register(MiddlewareConfiguration.self) { c in
            var middleware = MiddlewareConfiguration()
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

        // console
        s.register(Console.self) { c in
            return Terminal()
        }
        
        // server
        s.register(HTTPServer.Configuration.self) { c in
            return .init()
        }
        s.register(Server.self) { c in
            return try c.make(HTTPServer.self)
        }
        s.register(HTTPServer.self) { c in
            return try .init(application: c.make(), configuration: c.make())
        }
        s.register(Responder.self) { c in
            // initialize all `[Middleware]` from config
            let middleware = try c
                .make(MiddlewareConfiguration.self)
                .resolve()
            
            // create HTTP routes
            let routes = try c.make(Routes.self)
            
            // return new responder
            return ApplicationResponder(routes: routes, middleware: middleware)
        }

        // commands
        s.register(ServeCommand.self) { c in
            return try .init(server: c.make())
        }
        s.register(RoutesCommand.self) { c in
            return try .init(routes: c.make())
        }
        s.register(BootCommand.self) { c in
            return .init()
        }
        s.register(CommandConfiguration.self) { c in
            return try .default(on: c)
        }
        s.register(Commands.self) { c in
            return try c.make(CommandConfiguration.self).resolve()
        }

        // directory
        s.register(DirectoryConfig.self) { c in
            return .detect()
        }

        // logging
        s.register(ConsoleLogger.self) { container in
            return try ConsoleLogger(console: container.make())
        }
        s.register(Logger.self) { c in
            return try c.make(Application.self).logger
        }

        // templates
        #warning("TODO: update view renderer")
//        services.register(ViewRenderer.self) { container -> PlaintextRenderer in
//            let dir = try container.make(DirectoryConfig.self)
//            return PlaintextRenderer.init(viewsDir: dir.workDir + "Resources/Views/", on: container)
//        }

        // file
        s.register(NonBlockingFileIO.self) { c in
            return try .init(threadPool: c.make())
        }
        s.register(FileIO.self) { c in
            return try .init(io: c.make(), allocator: c.make(), on: c.eventLoop)
        }
        s.register(ByteBufferAllocator.self) { c in
            return .init()
        }

        // websocket
        #warning("TODO: update websocket client")
        // services.register(NIOWebSocketClient.self)

        return s
    }
}
