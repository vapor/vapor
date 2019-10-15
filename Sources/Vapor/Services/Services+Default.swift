extension Application {
    /// Vapor's default services. This includes many services required to successfully
    /// boot an Application. Only for special use cases should you create an empty `Services` struct.
    public static func `default`(environment: Environment = .development) -> Application {
        let app = Application(environment: environment)

        // client
        app.register(HTTPClient.Configuration.self) { c in
            return .init()
        }
        app.register(Client.self) { c in
            return try c.make(HTTPClient.self)
        }
        app.register(singleton: HTTPClient.self, boot: { app in
            return try .init(eventLoopGroupProvider: .shared(app.eventLoopGroup), configuration: app.make())
        }, shutdown: { s in
            try s.syncShutdown()
        })

        // ws client
        app.register(WebSocketClient.Configuration.self) { c in
            return .init()
        }
        app.register(WebSocketClient.self) { app in
            return try .init(eventLoopGroupProvider: .shared(app.eventLoopGroup), configuration: app.make())
        }

        // auth
        app.register(PasswordVerifier.self) { c in
            return try c.make(BCryptDigest.self)
        }
        app.register(BCryptDigest.self) { c in
            return Bcrypt
        }
        app.register(PlaintextVerifier.self) { c in
            return PlaintextVerifier()
        }
        app.register(PasswordVerifier.self) { c in
            return try c.make(PlaintextVerifier.self)
        }
        
        // routes
        app.register(Routes.self) { app in
            return .init()
        }
        
        // sessions
        app.register(SessionsMiddleware.self) { c in
            return try .init(sessions: c.make(), config: c.make())
        }
        app.register(Sessions.self) { c in
            return try c.make(MemorySessions.self)
        }
        app.register(MemorySessions.self) { app in
            return try MemorySessions(storage: app.make(), on: app.eventLoopGroup)
        }
        app.register(singleton: MemorySessions.Storage.self) { app in
            return .init()
        }
        
        app.register(SessionsConfig.self) { c in
            return .default()
        }

        // middleware
        app.register(MiddlewareConfiguration.self) { c in
            var middleware = MiddlewareConfiguration()
            try middleware.use(c.make(ErrorMiddleware.self))
            return middleware
        }
        app.register(FileMiddleware.self) { c in
            return try .init(
                publicDirectory: c.make(DirectoryConfiguration.self).publicDirectory,
                fileio: c.make()
            )
        }
        app.register(ErrorMiddleware.self) { c in
            return .default(environment: c.environment)
        }

        // console
        app.register(Console.self) { c in
            return Terminal()
        }
        
        // server
        app.register(HTTPServer.Configuration.self) { c in
            return .init()
        }
        app.register(Server.self) { c in
            return try c.make(HTTPServer.self)
        }
        app.register(HTTPServer.self) { app in
            return try .init(application: app, configuration: app.make())
        }
        app.register(Responder.self) { c in
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
        app.register(ServeCommand.self) { c in
            return try .init(server: c.make())
        }
        app.register(RoutesCommand.self) { c in
            return try .init(routes: c.make())
        }
        app.register(BootCommand.self) { c in
            return .init()
        }
        app.register(CommandConfiguration.self) { c in
            return try .default(on: c)
        }
        app.register(Commands.self) { c in
            return try c.make(CommandConfiguration.self).resolve()
        }

        // directory
        app.register(DirectoryConfiguration.self) { c in
            return .detect()
        }

        // logging
        app.register(ConsoleLogger.self) { container in
            return try ConsoleLogger(console: container.make())
        }
        app.register(Logger.self) { app in
            return app.logger
        }

        // view
        app.register(ViewRenderer.self) { c in
            return try c.make(PlaintextRenderer.self)
        }
        app.register(PlaintextRenderer.self) { app in
            return try PlaintextRenderer(
                threadPool: app.threadPool,
                viewsDirectory: app.make(DirectoryConfiguration.self).viewsDirectory,
                eventLoopGroup: app.eventLoopGroup
            )
        }

        // file
        app.register(NonBlockingFileIO.self) { app in
            return .init(threadPool: app.threadPool)
        }
        app.register(FileIO.self) { app in
            return try .init(io: app.make(), allocator: app.make())
        }
        app.register(ByteBufferAllocator.self) { c in
            return .init()
        }
        return app
    }
}
