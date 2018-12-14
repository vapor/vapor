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
    private let config: HTTPServerConfig
    
    private let console: Console
    
    private let application: Application
    
    /// Hold the current worker. Used for deinit.
    private var currentWorker: EventLoopGroup?

    /// Create a new `ServeCommand`.
    public init(
        config: HTTPServerConfig,
        console: Console,
        application: Application
    ) {
        self.config = config
        self.console = console
        self.application = application
    }

    /// See `Command`.
    public func run(using context: CommandContext) throws -> EventLoopFuture<Void> {
        return self.start(
            hostname: context.options["hostname"]
                // 0.0.0.0:8080, 0.0.0.0, parse hostname
                ?? context.options["bind"]?.split(separator: ":").first.flatMap(String.init),
            port: context.options["port"].flatMap(Int.init)
                // 0.0.0.0:8080, :8080, parse port
                ?? context.options["bind"]?.split(separator: ":").last.flatMap(String.init).flatMap(Int.init)
        )
    }
    
    private func start(hostname: String?, port: Int?) -> EventLoopFuture<Void> {
        // determine which hostname / port to bind to
        let hostname = hostname ?? self.config.hostname
        let port = port ?? self.config.port
        
        // print starting message
        self.console.print("Server starting on ", newLine: false)
        self.console.output("http://" + hostname, style: .init(color: .cyan), newLine: false)
        self.console.output(":" + port.description, style: .init(color: .cyan))
        
        // create caches
        let containerCache = ThreadSpecificVariable<ThreadContainer>()
        let responderCache = ThreadSpecificVariable<ThreadResponder>()
        
        // create this server's own event loop group
        let group = MultiThreadedEventLoopGroup(numberOfThreads: config.workerCount)
        self.currentWorker = group
        for _ in 0..<self.config.workerCount {
            // initialize each event loop
            let eventLoop = group.next()
            // perform cache set on the event loop
            _ = eventLoop.submit {
                _ = self.application.makeContainer(on: eventLoop).thenThrowing { container in
                    let responder = try container.make(Responder.self)
                    containerCache.currentValue = ThreadContainer(container: container)
                    responderCache.currentValue = ThreadResponder(responder: responder)
                }.mapIfError {
                    ERROR("Could not boot EventLoop: \($0).")
                }
            }.mapIfError {
                ERROR("Could not boot EventLoop: \($0).")
            }
        }
        
        // http upgrade
        var upgraders: [HTTPProtocolUpgrader] = []
        
        // web socket upgrade
        #warning("TODO: update websocket server")
//            if let wss = try? container.make(WebSocketServer.self) {
//                let ws = HTTPServer.webSocketUpgrader(maxFrameSize: config.webSocketMaxFrameSize, shouldUpgrade: { req in
//                    guard let subContainer = containerCache.currentValue?.container else {
//                        ERROR("[WebSocket Upgrader] Missing container (shouldUpgrade).")
//                        return nil
//                    }
//                    return wss.webSocketShouldUpgrade(for: Request(http: req, using: subContainer))
//                }, onUpgrade: { ws, req in
//                    guard let subContainer = containerCache.currentValue?.container else {
//                        ERROR("[WebSocket Upgrader] Missing container (onUpgrade).")
//                        return
//                    }
//                    return wss.webSocketOnUpgrade(ws, for: Request(http: req, using: subContainer))
//                })
//                upgraders.append(ws)
//            }
        
        // http responder
        let httpResponder = NIOServerResponder(containerCache: containerCache, responderCache: responderCache)
        
        // start the actual HTTPServer
        return HTTPServer.start(
            hostname: hostname,
            port: port,
            responder: httpResponder,
            maxBodySize: config.maxBodySize,
            backlog: config.backlog,
            reuseAddress: config.reuseAddress,
            tcpNoDelay: config.tcpNoDelay,
            upgraders: upgraders,
            on: group
        ) { error in
            #warning("TODO: use sswg logger")
            print(error)
            // logger.report(error: error, verbose: !self.container.environment.isRelease)
        }.map { server in
            self.application.runningServer = RunningServer(onClose: server.onClose, close: server.close)
        }
    }

    
    /// Called when the server deinitializes.
    deinit {
        currentWorker?.shutdownGracefully {
            if let error = $0 {
                ERROR("shutting down server event loop: \(error)")
            }
        }
    }
}

// MARK: Private

private struct NIOServerResponder: HTTPServerResponder {
    let containerCache: ThreadSpecificVariable<ThreadContainer>
    let responderCache: ThreadSpecificVariable<ThreadResponder>
    
    func respond(to http: HTTPRequest, on eventLoop: EventLoop) -> EventLoopFuture<HTTPResponse> {
        guard let container = containerCache.currentValue?.container else {
            let error = VaporError(identifier: "serverContainer", reason: "Missing server container.")
            return eventLoop.makeFailedFuture(error: error)
        }
        let req = HTTPRequestContext(http: http, on: eventLoop)
        guard let responder = responderCache.currentValue?.responder else {
            let error = VaporError(identifier: "serverResponder", reason: "Missing responder.")
            return eventLoop.makeFailedFuture(error: error)
        }
        return responder.respond(to: req)
    }
}

private final class ThreadContainer {
    var container: Container
    init(container: Container) {
        self.container = container
    }
}

private final class ThreadResponder {
    var responder: Responder
    init(responder: Responder) {
        self.responder = responder
    }
}
