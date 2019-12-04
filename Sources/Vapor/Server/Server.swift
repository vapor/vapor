public final class Server {
    let application: Application
    public var configuration: HTTPServer.Configuration
    
    public struct Running {
        let server: HTTPServer
        public func shutdown() {
            self.server.shutdown()
        }
    }
    
    init(_ application: Application) {
        self.application = application
        self.configuration = .init()
    }
    
    public func start(hostname: String? = nil, port: Int? = nil) throws -> Running {
        var configuration = self.configuration
        // determine which hostname / port to bind to
        configuration.hostname = hostname ?? self.configuration.hostname
        configuration.port = port ?? self.configuration.port
        let server = HTTPServer(
            application: self.application,
            responder: self.application.responder,
            router: self.application.router,
            configuration: configuration,
            on: self.application.eventLoopGroup
        )
        try server.start()
        return Running(server: server)
    }
}
