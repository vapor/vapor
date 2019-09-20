extension Services {
    /// Vapor's default services. This includes many services required to successfully
    /// boot an Application. Only for special use cases should you create an empty `Services` struct.
    public static func `default`() -> Services {
        var s = Services()

        // client
        s.register(HTTPClient.Configuration.self) { c in
            return .init()
        }
        s.register(Client.self) { c in
            return try c.make(HTTPClient.self)
        }
        s.singleton(HTTPClient.self, boot: { c in
            return try .init(eventLoopGroupProvider: .shared(c.eventLoop), configuration: c.make())
        }, shutdown: { s in
            try s.syncShutdown()
        })

        // ws client
        s.register(WebSocketClient.Configuration.self) { c in
            return .init()
        }
        s.register(WebSocketClient.self) { c in
            return try .init(eventLoopGroupProvider: .shared(c.eventLoop), configuration: c.make())
        }

        // auth
        s.register(PasswordVerifier.self) { c in
            return try c.make(BCryptDigest.self)
        }
        s.register(BCryptDigest.self) { c in
            return Bcrypt
        }
        s.register(PlaintextVerifier.self) { c in
            return PlaintextVerifier()
        }
        s.register(PasswordVerifier.self) { c in
            return try c.make(PlaintextVerifier.self)
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
        s.global(MemorySessions.Storage.self) { app in
            return .init()
        }
        
        s.register(SessionsConfig.self) { c in
            return .default()
        }

        // middleware
        s.register(MiddlewareConfiguration.self) { c in
            var middleware = MiddlewareConfiguration()
            try middleware.use(c.make(ErrorMiddleware.self))
            return middleware
        }
        s.register(FileMiddleware.self) { c in
            return try .init(
                publicDirectory: c.make(DirectoryConfiguration.self).publicDirectory,
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
            return try .init(application: c.application, configuration: c.make())
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
        s.register(DirectoryConfiguration.self) { c in
            return .detect()
        }

        // logging
        s.register(ConsoleLogger.self) { container in
            return try ConsoleLogger(console: container.make())
        }
        s.register(Logger.self) { c in
            return try c.application.logger
        }

        // view
        s.register(ViewRenderer.self) { c in
            return try c.make(PlaintextRenderer.self)
        }
        s.register(PlaintextRenderer.self) { c in
            return try PlaintextRenderer(
                threadPool: c.make(NIOThreadPool.self),
                viewsDirectory: c.make(DirectoryConfiguration.self).viewsDirectory,
                eventLoop: c.eventLoop
            )
        }

        // file
        s.register(NonBlockingFileIO.self) { c in
            return .init(threadPool: c.application.threadPool)
        }
        s.register(FileIO.self) { c in
            return try .init(io: c.make(), allocator: c.make(), on: c.eventLoop)
        }
        s.register(ByteBufferAllocator.self) { c in
            return .init()
        }

        return s
    }
}
