/// An `Engine` based `Server` implementation. This is Vapor's default and recommended HTTP server.
///
/// Use `EngineServerConfig` to configure how this server behaves. You should rarely need to use the `EngineServer` class directly.
public final class EngineServer: Server, Service {
    /// Specified configuration for this server.
    ///
    /// See `EngineServerConfig`.
    public let config: EngineServerConfig

    /// Main container for this server. All `EventLoop` containers will be created as `SubContainer`s
    /// from this parent `Container`.
    public let container: Container

    /// Create a new `EngineServer` using `EngineServerConfig` struct.
    ///
    /// - parameters:
    ///     - config: `EngineServerConfig` specifying this server's behavior.
    ///     - container: The server's main `Container`.
    public init(
        config: EngineServerConfig,
        container: Container
    ) {
        self.config = config
        self.container = container
    }

    /// Start the server. `Server` protocol requirement.
    ///
    /// See `Server`.
    public func start(hostname: String?, port: Int?) -> Future<Void> {
        let container = self.container
        let config = self.config

        return Future.flatMap(on: container) {
            let console = try container.make(Console.self)
            let logger = try container.make(Logger.self)

            let hostname = hostname ?? config.hostname
            let port = port ?? config.port

            console.print("Server starting on ", newLine: false)
            console.output("http://" + hostname, style: .init(color: .cyan), newLine: false)
            console.output(":" + port.description, style: .init(color: .cyan))

            let group = MultiThreadedEventLoopGroup(numThreads: config.workerCount)

            /// http upgrade
            var upgraders: [HTTPProtocolUpgrader] = []

            /// web socket upgrade
            if let wss = try? container.make(WebSocketServer.self) {
                let ws = WebSocket.httpProtocolUpgrader(shouldUpgrade: { req in
                    let container = Thread.current.cachedSubContainer(for: self.container, on: group.next())
                    return wss.webSocketShouldUpgrade(for: Request(http: req, using: container))
                }, onUpgrade: { ws, req in
                    let container = Thread.current.cachedSubContainer(for: self.container, on: group.next())
                    return wss.webSocketOnUpgrade(ws, for: Request(http: req, using: container))
                })
                upgraders.append(ws)
            }

            return HTTPServer.start(
                hostname: hostname,
                port: port,
                responder: EngineResponder(rootContainer: container),
                maxBodySize: config.maxBodySize,
                backlog: config.backlog,
                reuseAddress: config.reuseAddress,
                tcpNoDelay: config.tcpNoDelay,
                upgraders: upgraders,
                on: group
            ) { error in
                logger.reportError(error)
            }.map(to: Void.self) { server in
                if let app = container as? Application {
                    app.runningServer = RunningServer(onClose: server.onClose, close: server.close)
                }
            }
        }
    }
}

// MARK: Private

/// Private `HTTPResponder` implementation for `EngineServer`.
fileprivate struct EngineResponder: HTTPResponder {
    /// The engine's root responder.
    let rootContainer: Container

    /// Creates a new `EngineResponder`.
    init(rootContainer: Container) {
        self.rootContainer = rootContainer
    }

    /// See `HTTPResponder`
    func respond(to request: HTTPRequest, on worker: Worker) -> Future<HTTPResponse> {
        let container = Thread.current.cachedSubContainer(for: rootContainer, on: worker)
        return Future.flatMap(on: worker) {
            let responder = try Thread.current.cachedResponder(for: container)
            let req = Request(http: request, using: container)
            return try responder.respond(to: req).map(to: HTTPResponse.self) { $0.http }
        }
    }
}

extension Thread {
    /// Returns this `EventLoop`'s `SubContainer`, or creates a new one and caches it.
    fileprivate func cachedSubContainer(for container: Container, on worker: Worker) -> SubContainer {
        let subContainer: SubContainer
        if let existing = threadDictionary["subcontainer"] as? SubContainer {
            subContainer = existing
        } else {
            let new = container.subContainer(on: worker)
            subContainer = new
            threadDictionary["subcontainer"] = new
        }
        return subContainer
    }

    /// Returns this `EventLoop`'s `Responder`, or creates a new one and caches it.
    fileprivate func cachedResponder(for container: Container) throws -> Responder {
        let responder: Responder
        if let existing = threadDictionary["responder"] as? ApplicationResponder {
            responder = existing
        } else {
            let new = try container.make(Responder.self)
            responder = new
            threadDictionary["responder"] = new
        }
        return responder
    }
}
