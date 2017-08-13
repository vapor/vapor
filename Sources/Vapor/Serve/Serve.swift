import Command
import Console
import HTTP
import libc
import Sockets
import Service

/// Serves the droplet.
public final class Serve: Command {
    public let signature: CommandSignature
    public let server: ServerFactoryProtocol
    public let console: Console
    public let responder: Responder
    public let log: LogProtocol
    public let config: ServerConfig

    public init(
        console: Console,
        server: ServerFactoryProtocol,
        responder: Responder,
        log: LogProtocol,
        config: ServerConfig
    ) {
        self.signature = .init(
            arguments: [],
            options: [
                .init(name: "port", help: ["Overrides the default serving port."]),
                .init(name: "workdir", help: ["Overrides the working directory to a custom path."])
            ],
            help: ["Boots the Droplet's servers and begins accepting requests."]
        )
        self.console = console
        self.server = server
        self.responder = responder
        self.log = log
        self.config = config
    }

    public func run(using console: Console, with input: CommandInput) throws {
        do {
            let server = try self.server.makeServer(
                hostname: config.hostname,
                port: config.port,
                config.securityLayer
            )
            
            try console.info("Starting server on \(config.hostname):\(config.port)")
            try server.start(responder) { error in
                /// This error is thrown on read timeouts and is providing excess logging of expected behavior.
                /// We will continue to work to resolve the underlying issue associated with this error.
                ///https://github.com/vapor/vapor/issues/678
                if
                    case .dispatch(let dispatch) = error,
                    let sockets = dispatch as? SocketsError,
                    sockets.number == 35
                {
                    return
                }
                
                self.log.error("Server error: \(error)")
            }
            
            // don't enforce -> Never on protocol because of Swift warnings
            log.error("server did not block execution")
            exit(1)
        } catch ServerError.bind(let host, let port, _) {
            try console.error("Could not bind to \(host):\(port), it may be in use or require sudo.")
        } catch {
            try console.error("Serve error: \(error)")
        }
    }
}

// MARK: Service

extension Serve: ServiceType {
    /// See Service.serviceName
    public static var serviceName: String {
        return "serve"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [Command.self]
    }

    /// See Service.make
    public static func makeService(for container: Container) throws -> Serve? {
        guard let drop = container as? Droplet else {
            throw "serve command requires droplet container"
        }

        return try .init(
            console: container.make(Console.self),
            server: container.make(ServerFactoryProtocol.self),
            responder :drop.responder, // FIXME
            log: container.make(LogProtocol.self),
            config: container.make(ServerConfig.self)
        )
    }
}
