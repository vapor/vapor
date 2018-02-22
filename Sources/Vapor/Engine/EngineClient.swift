import Async
import HTTP
import TCP
import TLS
#if os(Linux)
    import OpenSSL
#else
    import AppleTLS
#endif

/// HTTP/1.1 client wrapper.
///
/// Able to more eeasily make request to HTTP servers
///
/// Automatically follows redirections as specified in the `EngineClientConfig`
/// Redirections modify the input `Request`
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
        return self.respond(to: req, maxRedirects: config.maxRedirections)
    }
    
    /// Responds to a request, applying redirections
    private func respond(to req: Request, maxRedirects redirects: Int) -> Future<Response> {
        return Future.flatMap {
            if req.http.uri.scheme == "https" ? true : false {
                return try self.tlsRespond(to: req, maxRedirects: redirects)
            } else {
                return try self.plaintextRespond(to: req, maxRedirects: redirects)
            }
        }
    }
    
    /// Rediects the input request with the `Location` in the Response
    private func redirect(
        _ response: HTTPResponse,
        for req: Request,
        maxRedirects redirects: Int
    ) throws -> Future<Response> {
        guard redirects > 0 else {
            throw VaporError(
                identifier: "excessiveRedirects",
                reason: "The HTTP Client was redirected more than \(config.maxRedirections) times.",
                source: .capture()
            )
        }
        
        guard let location = response.headers[.location] else {
            throw VaporError(
                identifier: "invalidRedirect",
                reason: "The HTTP Client received a status 3xx without a location to redirect to.",
                source: .capture()
            )
        }
        
        let newURI = try location.makeURI()
        
        if newURI.hostname != nil {
            req.http.uri = newURI
        } else {
            if newURI.path.first == "/" {
                req.http.uri.path = newURI.path
            } else {
                var path = newURI.path
                path.removeFirst()
                
                if req.http.uri.path.last == "/" {
                    req.http.uri.path += path
                } else {
                    var components = req.http.uri.path.split(separator: "/")
                    components.removeLast()
                    req.http.uri.path = components.joined(separator: "/") + "/" + path
                }
            }
        }
        
        return self.respond(to: req, maxRedirects: redirects - 1)
    }
    
    /// Processes an HTTP esponse and acts upon redirects accordingly
    private func response(
        from httpRes: HTTPResponse,
        for req: Request,
        maxRedirects redirects: Int
    ) throws -> Future<Response> {
        if httpRes.status.code >= 300 && httpRes.status.code < 400 {
            switch httpRes.status.code {
            case 301, 307, 308:
                return try redirect(httpRes, for: req, maxRedirects: redirects)
            case 302, 303:
                req.http.method = .get
                req.http.body = HTTPBody()
                req.http.mediaType = nil
                return try redirect(httpRes, for: req, maxRedirects: redirects)
            default: break
            }
        }
        
        let res = req.makeResponse()
        res.http = httpRes
        return Future(res)
    }

    /// Responds to a Request using TLS client.
    private func tlsRespond(to req: Request, maxRedirects redirects: Int) throws -> Future<Response> {
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
            on: self.container
        )
        req.http.headers[.host] = hostname
        return client.send(req.http).flatMap(to: Response.self) { httpRes in
            tlsClient.close()
            
            return try self.response(from: httpRes, for: req, maxRedirects: redirects)
        }
    }

    /// Responds to a Request using TCP client.
    private func plaintextRespond(to req: Request, maxRedirects redirects: Int) throws -> Future<Response> {
        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpClient = try TCPClient(socket: tcpSocket)
        let hostname = try req.http.uri.requireHostname()
        try tcpClient.connect(hostname: hostname, port: req.http.uri.port ?? 80)
        let promise = Promise(Response.self)
        let stream = tcpSocket.stream(on: self.container) { _, error in
            promise.fail(error)
        }
        let client = HTTPClient(
            stream: stream,
            on: self.container
        )
        req.http.headers[.host] = hostname
        return client.send(req.http).flatMap(to: Response.self) { httpRes in
            tcpClient.close()
            
            return try self.response(from: httpRes, for: req, maxRedirects: redirects)
        }
    }
}

/// Configuration option's for the EngineClient.
public struct EngineClientConfig: Service {
    /// The maximum response size to allow for
    /// incoming HTTP responses.
    public var maxResponseHeaderSize: Int
    
    /// The maximum amount of 3xx redirect responses to follow
    ///
    /// Used to prevent infinite redirect loops
    public var maxRedirections: Int

    /// Create a new EngineClientConfig.
    public init() {
        self.maxResponseHeaderSize = 100_000
        self.maxRedirections = 8
    }
}

extension URI {
    /// Returns the URI hostname, throwing if none exists.
    fileprivate func requireHostname() throws -> String {
        guard let hostname = self.hostname else {
            throw VaporError(identifier: "requireHostname", reason: "URI with hostname required.", source: .capture())
        }
        return hostname
    }
}
