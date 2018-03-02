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
    public func start() throws {
        let console = try container.make(Console.self, for: EngineServer.self)
        let logger = try container.make(Logger.self, for: EngineServer.self)

        let server = HTTPServer(responder: EngineResponder(rootContainer: container))

        console.print("Server starting on ", newLine: false)
        console.output("http://" + config.hostname, style: .init(color: .cyan), newLine: false)
        console.output(":" + config.port.description, style: .init(color: .cyan))

        // FIXME: error logging support
        //            server.onError = { error in
        //                logger.reportError(error, as: "Server Error")
        //            }

        try server.start(hostname: config.hostname, port: Int(config.port)).wait()
    }
}

struct EngineResponder: HTTPResponder {
    let rootContainer: Container
    init(rootContainer: Container) {
        self.rootContainer = rootContainer
    }

    func respond(to request: HTTPRequest) -> Future<HTTPResponse> {
        let container: SubContainer
        if let existing = Thread.current.threadDictionary["subcontainer"] as? SubContainer {
            container = existing
        } else {
            let new = rootContainer.subContainer(on: request)
            container = new
            Thread.current.threadDictionary["subcontainer"] = new
        }

        let responder: Responder
        if let existing = Thread.current.threadDictionary["responder"] as? ApplicationResponder {
            responder = existing
        } else {
            let new = try! container.make(Responder.self, for: EngineServer.self)
            responder = new
            Thread.current.threadDictionary["responder"] = new
        }

        let req = Request(http: request, using: container)
        return try! responder.respond(to: req).map(to: HTTPResponse.self) { $0.http }
    }
}

extension Logger {
    func reportError(_ error: Error, as label: String) {
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
    /// Host name the server will bind to.
    public var hostname: String

    /// Port the server will bind to.
    public var port: UInt16

    /// Listen backlog.
    public var backlog: Int32

    /// Number of client accepting workers.
    /// Should be equal to the number of logical cores.
    public var workerCount: Int
    
    /// Limits the amount of connections per IP address to prevent certain Denial of Service attacks
    public var maxConnectionsPerIP: Int
    
    /// The SSL configuration. If it exists, SSL will be used
    // public var ssl: EngineServerSSLConfig?

    /// Creates a new engine server config
    public init(
        hostname: String,
        port: UInt16,
        backlog: Int32,
        workerCount: Int,
        maxConnectionsPerIP: Int
    ) {
        self.hostname = hostname
        self.port = port
        self.workerCount = workerCount
        self.backlog = backlog
        self.maxConnectionsPerIP = maxConnectionsPerIP
        // self.ssl = nil
    }
}

extension EngineServerConfig {
    /// Detects `EngineServerConfig` from the environment.
    public static func detect(
        hostname: String = "localhost",
        port: UInt16 = 8080,
        backlog: Int32 = 4096,
        workerCount: Int = ProcessInfo.processInfo.activeProcessorCount,
        maxConnectionsPerIP: Int = 128
    ) throws -> EngineServerConfig {
        return try EngineServerConfig(
            hostname: CommandInput.commandLine.parse(option: .value(name: "hostname")) ?? hostname,
            port: CommandInput.commandLine.parse(option: .value(name: "port")).flatMap(UInt16.init) ?? port,
            backlog: backlog,
            workerCount: workerCount,
            maxConnectionsPerIP: maxConnectionsPerIP
        )
    }
}
