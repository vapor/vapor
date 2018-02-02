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
        return self.respond(to: req, redirecting: config.maxRedirections)
    }
    
    /// Responds to a request, applying redirections
    private func respond(to req: Request, redirecting: Int) -> Future<Response> {
        return Future.flatMap {
            if req.http.uri.scheme == "https" ? true : false {
                return try self.tlsRespond(to: req, redirecting: redirecting)
            } else {
                return try self.plaintextRespond(to: req, redirecting: redirecting)
            }
        }
    }
    
    private func response(
        from httpRes: HTTPResponse,
        for req: Request,
        redirecting: Int
    ) throws -> Future<Response> {
        if httpRes.status.code >= 301 && httpRes.status.code <= 303 {
            guard redirecting > 0 else {
                throw VaporError(
                    identifier: "excessive-redirects",
                    reason: "The HTTP Client was redirected more than \(config.maxRedirections) times."
                )
            }
            
            guard let location = httpRes.headers[.location] else {
                throw VaporError(
                    identifier: "invalid-redirect",
                    reason: "The HTTP Client received a status 3xx without a location to redirect to."
                )
            }
            
            req.http.uri = try location.makeURI()
            
            return self.respond(to: req, redirecting: redirecting - 1)
        }
        
        let res = req.makeResponse()
        res.http = httpRes
        return Future(res)
    }

    /// Responds to a Request using TLS client.
    private func tlsRespond(to req: Request, redirecting: Int) throws -> Future<Response> {
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
        return client.send(req.http).flatMap(to: Response.self) { httpRes in
            tlsClient.close()
            
            return try self.response(from: httpRes, for: req, redirecting: redirecting)
        }
    }

    /// Responds to a Request using TCP client.
    private func plaintextRespond(to req: Request, redirecting: Int) throws -> Future<Response> {
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
        return client.send(req.http).flatMap(to: Response.self) { httpRes in
            tcpClient.close()
            
            return try self.response(from: httpRes, for: req, redirecting: redirecting)
        }
    }
}

/// Configuration option's for the EngineClient.
public struct EngineClientConfig: Service {
    /// The maximum response size to allow for
    /// incoming HTTP responses.
    public let maxResponseSize: Int
    
    /// The maximum amount of 3xx redirect responses to follow
    ///
    /// Used to prevent infinite redirect loops
    public var maxRedirections: Int

    /// Create a new EngineClientConfig.
    public init(maxResponseSize: Int) {
        self.maxResponseSize = maxResponseSize
        self.maxRedirections = 3
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
