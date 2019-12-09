extension Application {
    public var routes: Routes {
        self.http.routes
    }
    
    public var middleware: Middlewares {
        get { self.http.middleware }
        set { self.http.middleware = newValue }
    }
    
    public var router: Router {
        ApplicationRouter(
            routes: self.routes,
            middleware: self.middleware.resolve())
    }
    
    public var server: Server {
        self.http.server
    }
    
    public var client: Client {
        self.http.client
    }
    
    var http: HTTP {
        self.providers.require(HTTP.self)
    }
}

public final class HTTP: Provider {
    var routes: Routes
    var middleware: Middlewares
    var serveCommand: ServeCommand
    var client: ApplicationClient
    var server: Server
    
    public let application: Application
    
    public init(_ application: Application) {
        self.routes = .init()
        self.middleware = .init()
        self.middleware.use(MetricsMiddleware()) // This should always be the first in the chain, so we time the entire request.
        self.middleware.use(ErrorMiddleware.default(environment: application.environment))
        self.serveCommand = ServeCommand(application: application)
        application.commands.use(self.serveCommand, as: "serve", isDefault: true)
        application.commands.use(RoutesCommand(routes: self.routes), as: "routes")
        
        self.server = .init(application)
        #warning("TODO: make configurable")
        self.client = ApplicationClient(http: .init(
            eventLoopGroupProvider: .shared(application.eventLoopGroup),
            configuration: .init()
        ))
        self.application = application
    }
    
    public func shutdown() {
        self.serveCommand.shutdown()
        try! self.client.http.syncShutdown()
    }
}
