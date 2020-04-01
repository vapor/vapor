extension Application.Servers.Provider {
    public static var http: Self {
        .init {
            $0.servers.use {
                ApplicationHTTPServer(application: $0)
            }
        }
    }
}

private final class ApplicationHTTPServer: Server {
    let application: Application
    var server: HTTPServer?

    init(application: Application) {
        self.application = application
        self.server = nil
    }

    func start(hostname: String?, port: Int?) throws {
        var configuration = self.application.http.server.configuration
        // determine which hostname / port to bind to
        configuration.hostname = hostname ?? configuration.hostname
        configuration.port = port ?? configuration.port

        let server = HTTPServer(
            application: self.application,
            responder: self.application.responder.current,
            configuration: configuration,
            on: self.application.eventLoopGroup
        )
        self.server = server
        try server.start()
    }

    func shutdown() {
        self.server?.shutdown()
    }
}
