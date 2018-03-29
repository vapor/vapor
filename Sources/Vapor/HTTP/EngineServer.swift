import Async
import Bits
import Console
import Command
import Debugging
import Dispatch
import Foundation
import HTTP
import Service

/// A TCP based server with HTTP parsing and serialization pipeline.
public final class EngineServer: Server, Service {
    /// Chosen configuration for this server.
    public let config: EngineServerConfig

    /// Container for setting on event loops.
    public let container: Container

    /// Create a new EngineServer using config struct.
    public init(
        config: EngineServerConfig,
        container: Container
    ) {
        self.config = config
        self.container = container
    }

    /// Start the server. Server protocol requirement.
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

struct EngineResponder: HTTPResponder {
    let rootContainer: Container
    init(rootContainer: Container) {
        self.rootContainer = rootContainer
    }

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
    func cachedSubContainer(for container: Container, on worker: Worker) -> SubContainer {
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


    func cachedResponder(for container: Container) throws -> Responder {
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

extension Logger {
    func reportError(_ error: Error) {
        var string = ""
        if let debuggable = error as? Debuggable {
            string += debuggable.fullIdentifier
            string += ": "
            string += debuggable.reason
        } else {
            string += "\(error)"
        }
        if let debuggable = error as? Debuggable {
            if let source = debuggable.sourceLocation {
                self.error(string,
                   file: source.file,
                   function: source.function,
                   line: source.line,
                   column: source.column
                )
            } else {
                self.error(string)
            }
            if debuggable.suggestedFixes.count > 0 {
                self.debug("Suggested fixes for \(debuggable.fullIdentifier): " + debuggable.suggestedFixes.joined(separator: " "))
            }
            if debuggable.possibleCauses.count > 0 {
                self.debug("Possible causes for \(debuggable.fullIdentifier): " + debuggable.possibleCauses.joined(separator: " "))
            }
        } else {
            self.error(string)
        }
    }
}

/// Engine server config struct.
public struct EngineServerConfig: Service {
    /// Detects `EngineServerConfig` from the environment.
    public static func `default`(
        hostname: String = "localhost",
        port: Int = 8080,
        backlog: Int = 256,
        workerCount: Int = ProcessInfo.processInfo.activeProcessorCount,
        maxBodySize: Int = 1_000_0000,
        reuseAddress: Bool = true,
        tcpNoDelay: Bool = true
    ) -> EngineServerConfig {
        return EngineServerConfig(
            hostname: hostname,
            port: port,
            backlog: backlog,
            workerCount: workerCount,
            maxBodySize: maxBodySize,
            reuseAddress: reuseAddress,
            tcpNoDelay: tcpNoDelay
        )
    }

    /// Host name the server will bind to.
    public var hostname: String

    /// Port the server will bind to.
    public var port: Int

    /// Listen backlog.
    public var backlog: Int

    /// Number of client accepting workers.
    /// Should be equal to the number of logical cores.
    public var workerCount: Int

    /// Requests containing bodies larger than this maximum will be rejected, closign the connection.
    public var maxBodySize: Int

    /// When `true`, can prevent errors re-binding to a socket after successive server restarts.
    public var reuseAddress: Bool

    /// When `true`, OS will attempt to minimize TCP packet delay.
    public var tcpNoDelay: Bool

    /// Creates a new engine server config
    public init(
        hostname: String,
        port: Int,
        backlog: Int,
        workerCount: Int,
        maxBodySize: Int,
        reuseAddress: Bool,
        tcpNoDelay: Bool
    ) {
        self.hostname = hostname
        self.port = port
        self.backlog = backlog
        self.workerCount = workerCount
        self.maxBodySize = maxBodySize
        self.reuseAddress = reuseAddress
        self.tcpNoDelay = tcpNoDelay
    }
}
