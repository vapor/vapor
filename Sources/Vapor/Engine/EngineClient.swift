import Async
import HTTP
import TCP
import TLS
#if os(Linux)
    import OpenSSL
#else
    import AppleTLS
#endif

/// HTTP/1.1 and HTTP/2 client wrapper.
public final class EngineClient: Client, Service {
    /// See Client.container
    public let container: Container

    /// This client's config.
    public let config: EngineClientConfig

    /// Create a new engine client
    public init(container: Container, config: EngineClientConfig) {
        self.container = container
        self.config = config
    }

    /// See Responder.respond
    public func respond(to req: Request) -> Future<Response> {
        return Future.flatMap {
            if req.http.uri.scheme == "https" ? true : false {
                return try self.tlsRespond(to: req)
            } else {
                return try self.plaintextRespond(to: req)
            }
        }
    }

    /// Responds to a Request using TLS client.
    private func tlsRespond(to req: Request) throws -> Future<Response> {
        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpClient = try TCPClient(socket: tcpSocket)
        var settings = TLSClientSettings()
        let hostname = try req.http.uri.requireHostname()
        settings.peerDomainName = hostname
        #if os(macOS)
            let tlsClient = try AppleTLSClient(tcp: tcpClient, using: settings)
        #else
            let tlsClient = try OpenSSLClient(tcp: tcpClient, using: settings)
        #endif
        try tlsClient.connect(hostname: hostname, port: req.http.uri.port ?? 443)
        let client = HTTPClient(
            stream: tlsClient.socket.stream(on: self.container),
            on: self.container,
            maxResponseSize: self.config.maxResponseSize
        )
        req.http.headers[.host] = hostname
        return client.send(req.http).map(to: Response.self) { httpRes in
            tlsClient.close()
            let res = req.makeResponse()
            res.http = httpRes
            return res
        }
    }

    /// Responds to a Request using TCP client.
    private func plaintextRespond(to req: Request) throws -> Future<Response> {
        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpClient = try TCPClient(socket: tcpSocket)
        let hostname = try req.http.uri.requireHostname()
        try tcpClient.connect(hostname: hostname, port: req.http.uri.port ?? 80)
        let client = HTTPClient(
            stream: tcpSocket.stream(on: self.container),
            on: self.container,
            maxResponseSize: self.config.maxResponseSize
        )
        req.http.headers[.host] = hostname
        return client.send(req.http).map(to: Response.self) { httpRes in
            tcpClient.close()
            let res = req.makeResponse()
            res.http = httpRes
            return res
        }
    }
}

/// Configuration option's for the EngineClient.
public struct EngineClientConfig: Service {
    /// The maximum response size to allow for
    /// incoming HTTP responses.
    public let maxResponseSize: Int

    /// Create a new EngineClientConfig.
    public init(maxResponseSize: Int) {
        self.maxResponseSize = maxResponseSize
    }
}

extension URI {
    /// Returns the URI hostname, throwing if none exists.
    fileprivate func requireHostname() throws -> String {
        guard let hostname = self.hostname else {
            throw VaporError(identifier: "requireHostname", reason: "URI with hostname required.")
        }
        return hostname
    }
}
