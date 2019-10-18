extension Application {
    func registerDefaultServices() {
        // core
        self.register(singleton: Running.self) { app in
            return Running()
        }
        self.register(singleton: NIOThreadPool.self, boot: { app in
            let pool = NIOThreadPool(numberOfThreads: 1)
            pool.start()
            return pool
        }, shutdown: { pool in
            try pool.syncShutdownGracefully()
        })
        self.register(EventLoopGroup.self) { app in
            return app.eventLoopGroup
        }
        self.register(EventLoop.self) { app in
            return try app.make(EventLoopGroup.self).next()
        }

        // client
        self.register(HTTPClient.Configuration.self) { app in
            return .init()
        }
        self.register(request: Client.self) { req in
            return try RequestClient(http: req.application.make(), req: req)
        }
        self.register(Client.self) { c in
            return try ApplicationClient(http: c.make())
        }
        self.register(singleton: HTTPClient.self, boot: { app in
            return try .init(
                eventLoopGroupProvider: .shared(app.make()),
                configuration: app.make()
            )
        }, shutdown: { s in
            try s.syncShutdown()
        })

        // ws client
        self.register(WebSocketClient.Configuration.self) { c in
            return .init()
        }
        self.register(WebSocketClient.self) { app in
            return try .init(eventLoopGroupProvider: .shared(app.make()), configuration: app.make())
        }

        // auth
        self.register(PasswordVerifier.self) { c in
            return try c.make(BCryptDigest.self)
        }
        self.register(BCryptDigest.self) { c in
            return Bcrypt
        }
        self.register(PlaintextVerifier.self) { c in
            return PlaintextVerifier()
        }
        self.register(PasswordVerifier.self) { c in
            return try c.make(PlaintextVerifier.self)
        }
        
        // routes
        self.register(Routes.self) { app in
            return .init()
        }
        
        // sessions
        self.register(SessionsMiddleware.self) { c in
            return try .init(sessions: c.make(), config: c.make())
        }
        self.register(Sessions.self) { c in
            return try c.make(MemorySessions.self)
        }
        self.register(MemorySessions.self) { app in
            return try MemorySessions(storage: app.make(), on: app.make())
        }
        self.register(singleton: MemorySessions.Storage.self) { app in
            return .init()
        }
        
        self.register(SessionsConfig.self) { c in
            return .default()
        }

        // middleware
        self.register(MiddlewareConfiguration.self) { c in
            var middleware = MiddlewareConfiguration()
            try middleware.use(c.make(ErrorMiddleware.self))
            return middleware
        }
        self.register(FileMiddleware.self) { c in
            return try .init(
                publicDirectory: c.make(DirectoryConfiguration.self).publicDirectory,
                fileio: c.make()
            )
        }
        self.register(ErrorMiddleware.self) { c in
            return .default(environment: c.environment)
        }

        // console
        self.register(Console.self) { c in
            return Terminal()
        }
        
        // server
        self.register(HTTPServer.Configuration.self) { c in
            return .init()
        }
        self.register(Server.self) { c in
            return try c.make(HTTPServer.self)
        }
        self.register(singleton: HTTPServer.self, boot: { app in
            return try .init(
                application: app,
                responder: app.make(),
                configuration: app.make(),
                on: app.make()
            )
        }, shutdown: { server in
            server.shutdown()
        })
        self.register(Responder.self) { c in
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
        self.register(singleton: ServeCommand.self, boot: { app in
            return try .init(server: app.make(), running: app.make())
        }, shutdown: { serve in
            serve.shutdown()
        })
        self.register(RoutesCommand.self) { c in
            return try .init(routes: c.make())
        }
        self.register(BootCommand.self) { c in
            return .init()
        }
        self.register(CommandConfiguration.self) { c in
            return try .default(on: c)
        }
        self.register(Commands.self) { c in
            return try c.make(CommandConfiguration.self).resolve()
        }

        // directory
        self.register(DirectoryConfiguration.self) { c in
            return .detect()
        }

        // logging
        self.register(ConsoleLogger.self) { container in
            return try ConsoleLogger(console: container.make())
        }
        self.register(Logger.self) { app in
            return .init(label: "codes.vapor.application")
        }

        // view
        self.register(ViewRenderer.self) { c in
            return try c.make(PlaintextRenderer.self)
        }
        self.register(PlaintextRenderer.self) { app in
            return try PlaintextRenderer(
                threadPool: app.make(),
                viewsDirectory: app.make(DirectoryConfiguration.self).viewsDirectory,
                eventLoopGroup: app.make()
            )
        }

        // file
        self.register(NonBlockingFileIO.self) { app in
            return try .init(threadPool: app.make())
        }
        self.register(FileIO.self) { app in
            return try .init(io: app.make(), allocator: app.make())
        }
        self.register(ByteBufferAllocator.self) { c in
            return .init()
        }
    }
}
