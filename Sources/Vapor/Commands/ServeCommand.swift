/// Starts serving the `Application`'s `Responder` over HTTP.
///
///     $ swift run Run serve
///     Server starting on http://localhost:8080
///
public final class HTTPServeCommand: Command {
    /// See `Command`.
    public var arguments: [CommandArgument] {
        return []
    }

    /// See `Command`.
    public var options: [CommandOption] {
        return [
            .value(name: "hostname", short: "H", help: ["Set the hostname the server will run on."]),
            .value(name: "port", short: "p", help: ["Set the port the server will run on."]),
            .value(name: "bind", short: "b", help: ["Convenience for setting hostname and port together."]),
        ]
    }

    /// See `Command`.
    public let help: [String] = ["Begins serving the app over HTTP."]

    /// The server to boot.
    private let config: HTTPServersConfig
    
    private let console: Console
    
    private let application: Application
    
    /// Hold the current worker. Used for deinit.
    private var currentWorker: EventLoopGroup?

    /// Create a new `ServeCommand`.
    public init(
        config: HTTPServersConfig,
        console: Console,
        application: Application
    ) {
        self.config = config
        self.console = console
        self.application = application
    }

    /// See `Command`.
    public func run(using context: CommandContext) throws -> EventLoopFuture<Void> {
        #warning("handle > 1 server where port is specified")
        return self.start(
            hostname: context.options["hostname"]
                // 0.0.0.0:8080, 0.0.0.0, parse hostname
                ?? context.options["bind"]?.split(separator: ":").first.flatMap(String.init),
            port: context.options["port"].flatMap(Int.init)
                // 0.0.0.0:8080, :8080, parse port
                ?? context.options["bind"]?.split(separator: ":").last.flatMap(String.init).flatMap(Int.init),
            on: context.eventLoop
        )
    }
    
    private func start(hostname: String?, port: Int?, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return .andAll(self.config.servers.map { server in
            return self.start(config: server, hostname: hostname, port: port)
        }, eventLoop: eventLoop)
    }
    
    private func start(config: HTTPServerConfig, hostname: String?, port: Int?) -> EventLoopFuture<Void> {
        // determine which hostname / port to bind to
        let hostname = hostname ?? config.hostname
        let port = port ?? config.port
        
        // print starting message
        self.console.print("Server starting on ", newLine: false)
        let scheme = config.tlsConfig == nil ? "http" : "https"
        self.console.output("\(scheme)://" + hostname, style: .init(color: .cyan), newLine: false)
        self.console.output(":" + port.description, style: .init(color: .cyan))
        
        // http responder
        let responderCache = ThreadSpecificVariable<ThreadResponder>()
        let httpResponder = NIOServerResponder(responderCache: responderCache, application: self.application)
        
        // start the actual HTTPServer
        return HTTPServer.start(
            config: config,
            delegate: httpResponder
        ).map { server in
            self.application.runningServer = RunningServer(onClose: server.onClose, close: server.close)
            server.onClose.whenComplete { _ in
                self.currentWorker?.shutdownGracefully {
                    if let error = $0 {
                        ERROR("shutting down server event loop: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: Private

private struct NIOServerResponder: HTTPServerDelegate {
    let responderCache: ThreadSpecificVariable<ThreadResponder>
    let application: Application
    
    func respond(to http: HTTPRequest, on channel: Channel) -> EventLoopFuture<HTTPResponse> {
        let req = HTTPRequestContext(http: http, channel: channel)
        if let responder = responderCache.currentValue?.responder {
            return responder.respond(to: req)
        } else {
            return self.application.makeContainer(on: channel.eventLoop).thenThrowing { container -> HTTPResponder in
                let responder = try container.make(HTTPResponder.self)
                self.responderCache.currentValue = ThreadResponder(responder: responder)
                return responder
            }.then { responder in
                return responder.respond(to: req)
            }
        }
        
    }
}

private final class ThreadResponder {
    var responder: HTTPResponder
    init(responder: HTTPResponder) {
        self.responder = responder
    }
}
