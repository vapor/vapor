import Core
import Dispatch
import HTTP

/// Connected Clients are capapble of serializing requests
/// to remote servers and parsing the responses.
public protocol ConnectedClient: Responder { }

/// Clients are capable of creating connected clients
/// using a supplied connected client config.
public protocol Client: Responder {
    /// Creates a connected client from the
    /// supplied configuration
    func makeConnectedClient(
        config: ConnectedClientConfig
    ) throws -> ConnectedClient
}

// MARK: Convenience

extension Client {
    public func makeConnectedClient(
        for req: Request
    ) throws -> ConnectedClient {
        let config = try ConnectedClientConfig(
            hostname: req.uri.hostname ?? "",
            port: req.uri.port ?? 80,
            queue: req.requireQueue()
        )
        return try makeConnectedClient(config: config)
    }

    public func respond(
        to req: Request
    ) throws -> Future<Response> {
        return try makeConnectedClient(for: req)
            .respond(to: req)
    }
}

/// Connected client config struct.
public struct ConnectedClientConfig {
    /// Host name the server will bind to.
    public let hostname: String

    /// Port the server will bind to.
    public let port: UInt16

    /// The queue on which to complete futures.
    public let queue: DispatchQueue

    /// Creates a new engine server config
    public init(
        hostname: String = "localhost",
        port: UInt16 = 8080,
        queue: DispatchQueue
    ) {
        self.hostname = hostname
        self.port = port
        self.queue = queue
    }
}
