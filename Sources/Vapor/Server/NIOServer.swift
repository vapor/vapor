/// Vapor's default `Server` implementation. Built on SwiftNIO-based `HTTPServer`.
public final class NIOServer: Server, ServiceType {
    /// See `ServiceType`.
    public static var serviceSupports: [Any.Type] { return [Server.self] }

    /// See `ServiceType`.
    public static func makeService(for container: Container) throws -> NIOServer {
        return try NIOServer(config: container.make(), container: container)
    }

    /// Chosen configuration for this server.
    public let config: NIOServerConfig

    /// Container for setting on event loops.
    public let container: Container

    /// Hold the current worker. Used for deinit.
    private var currentWorker: Worker?

    /// Create a new `NIOServer`.
    ///
    /// - parameters:
    ///     - config: Server preferences such as hostname, port, max body size, etc.
    ///     - container: Root service-container to use for all event loops the server will create.
    public init(config: NIOServerConfig, container: Container) {
        self.config = config
        self.container = container
    }

    /// See `Server`.
    public func start(hostname: String?, port: Int?) -> Future<Void> {
        do {
            // console + logger required for outputting messages and error info
            let console = try container.make(Console.self)
            let logger = try container.make(Logger.self)

            // determine which hostname / port to bind to
            let hostname = hostname ?? config.hostname
            let port = port ?? config.port

            // print starting message
            console.print("Server starting on ", newLine: false)
            console.output("http://" + hostname, style: .init(color: .cyan), newLine: false)
            console.output(":" + port.description, style: .init(color: .cyan))

            // create caches
            let containerCache = ThreadSpecificVariable<ThreadContainer>()
            let responderCache = ThreadSpecificVariable<ThreadResponder>()

            // create this server's own event loop group
            let group = MultiThreadedEventLoopGroup(numberOfThreads: config.workerCount)
            for _ in 0..<config.workerCount {
                // initialize each event loop
                let eventLoop = group.next()
                // perform cache set on the event loop
                eventLoop.submit {
                    let subContainer = self.container.subContainer(on: eventLoop)
                    let responder = try subContainer.make(Responder.self)
                    containerCache.currentValue = ThreadContainer(container: subContainer)
                    responderCache.currentValue = ThreadResponder(responder: responder)
                }.catch {
                    ERROR("Could not boot EventLoop: \($0).")
                }
            }

            // http upgrade
            var upgraders: [HTTPProtocolUpgrader] = []

            // web socket upgrade
            if let wss = try? container.make(WebSocketServer.self) {
                let ws = HTTPServer.webSocketUpgrader(maxFrameSize: config.webSocketMaxFrameSize, shouldUpgrade: { req in
                    guard let subContainer = containerCache.currentValue?.container else {
                        ERROR("[WebSocket Upgrader] Missing container (shouldUpgrade).")
                        return nil
                    }
                    return wss.webSocketShouldUpgrade(for: Request(http: req, using: subContainer))
                }, onUpgrade: { ws, req in
                    guard let subContainer = containerCache.currentValue?.container else {
                        ERROR("[WebSocket Upgrader] Missing container (onUpgrade).")
                        return
                    }
                    return wss.webSocketOnUpgrade(ws, for: Request(http: req, using: subContainer))
                })
                upgraders.append(ws)
            }

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
                logger.report(error: error, verbose: !self.container.environment.isRelease)
            }.map { server in
                if let app = self.container as? Application {
                    app.runningServer = RunningServer(onClose: server.onClose, close: server.close)
                }
            }
        } catch {
            return container.eventLoop.newFailedFuture(error: error)
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

    func respond(to http: HTTPRequest, on worker: Worker) -> EventLoopFuture<HTTPResponse> {
        guard let container = containerCache.currentValue?.container else {
            let error = VaporError(identifier: "serverContainer", reason: "Missing server container.")
            return worker.eventLoop.newFailedFuture(error: error)
        }
        let req = Request(http: http, using: container)
        guard let responder = responderCache.currentValue?.responder else {
            let error = VaporError(identifier: "serverResponder", reason: "Missing responder.")
            return worker.eventLoop.newFailedFuture(error: error)
        }
        do {
            // use #file to explicitly utilize NIO's non-throwing map
            return try responder.respond(to: req).map(file: #file) { $0.http }
        } catch {
            return worker.eventLoop.newFailedFuture(error: error)
        }
    }
}

private final class ThreadContainer {
    var container: SubContainer
    init(container: SubContainer) {
        self.container = container
    }
}

private final class ThreadResponder {
    var responder: Responder
    init(responder: Responder) {
        self.responder = responder
    }
}
