extension Application {
    public var routes: Routes {
        self.http.storage.routes
    }

    public var middleware: Middlewares {
        get { self.http.storage.middleware }
        set { self.http.storage.middleware = newValue }
    }

    public var responder: Responder {
        ApplicationResponder(Router(routes: self.routes, middleware: self.middleware.resolve()))
    }

    public var client: Client {
        self.http.storage.client
    }

    public struct Server {
        let application: Application

        public var configuration: HTTPServer.Configuration {
            get { self.application.http.storage.serverConfiguration }
            nonmutating set { self.application.http.storage.serverConfiguration = newValue }
        }

        public struct Running {
            let server: HTTPServer
            public func shutdown() {
                self.server.shutdown()
            }
        }

        public func start(hostname: String? = nil, port: Int? = nil) throws -> Running {
            var configuration = self.configuration
            // determine which hostname / port to bind to
            configuration.hostname = hostname ?? self.configuration.hostname
            configuration.port = port ?? self.configuration.port
            let server = HTTPServer(
                application: self.application,
                responder: self.application.responder,
                configuration: configuration,
                on: self.application.eventLoopGroup
            )
            try server.start()
            return Running(server: server)
        }
    }

    public var server: Server {
        .init(application: self)
    }

    public struct HTTP {
        final class Storage {
            var routes: Routes
            var middleware: Middlewares
            var serveCommand: ServeCommand
            var client: ApplicationClient
            var serverConfiguration: HTTPServer.Configuration

            init(environment: Environment, on eventLoopGroup: EventLoopGroup) {
                self.routes = .init()
                self.middleware = .init()
                self.middleware.use(ErrorMiddleware.default(environment: environment))
                self.serveCommand = ServeCommand()
                self.client = ApplicationClient(http: .init(
                    eventLoopGroupProvider: .shared(eventLoopGroup),
                    configuration: .init()
                ))
                self.serverConfiguration = .init()
            }
        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        struct LifecycleHandler: Vapor.LifecycleHandler {
            func shutdown(_ application: Application) {
                application.http.storage.serveCommand.shutdown()
                try! application.http.storage.client.http.syncShutdown()
            }
        }

        let application: Application

        var storage: Storage {
            guard let storage = self.application.storage[Key.self] else {
                fatalError("HTTP not configured. Configure with app.use(.http)")
            }
            return storage
        }

        func initialize() {
            self.application.storage[Key.self] = .init(
                environment: self.application.environment,
                on: self.application.eventLoopGroup
            )
            self.application.lifecycle.use(LifecycleHandler())
            self.application.commands.use(
                self.application.http.storage.serveCommand,
                as: "serve",
                isDefault: true
            )
            self.application.commands.use(RoutesCommand(), as: "routes")
        }

    }

    public var http: HTTP {
        .init(application: self)
    }
}
