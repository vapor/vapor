import HTTP
import Console
import Sockets

/// Serves the droplet.
public final class Serve: Command {
    public let signature: [Argument] = [
        Option(name: "port", help: ["Overrides the default serving port."]),
        Option(name: "workdir", help: ["Overrides the working directory to a custom path."])
    ]

    public let help: [String] = [
        "Boots the Droplet's servers and begins accepting requests."
    ]

    public let id: String = "serve"
    
    public let server: ServerFactoryProtocol
    public let console: ConsoleProtocol
    public let responder: Responder
    public let log: LogProtocol
    public let config: ServerConfig

    public init(
        _ console: ConsoleProtocol,
        _ server: ServerFactoryProtocol,
        _ responder: Responder,
        _ log: LogProtocol,
        _ config: ServerConfig
    ) {
        self.console = console
        self.server = server
        self.responder = responder
        self.log = log
        self.config = config
    }

    public func run(arguments: [String]) throws {
        do {
            let server = try self.server.makeServer(
                hostname: config.hostname,
                port: config.port,
                config.securityLayer
            )
            
            console.info("Starting server on \(config.hostname):\(config.port)")
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
        } catch ServerError.bind(let host, let port, _) {
            console.error("Could not bind to \(host):\(port), it may be in use or require sudo.")
        } catch {
            console.error("Serve error: \(error)")
        }

        exit(1)
    }
}
