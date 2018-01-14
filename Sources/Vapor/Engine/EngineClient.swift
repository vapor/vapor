import Async
import HTTP
/*import HTTP2*/
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
        let ssl = req.http.uri.scheme == "https" ? true : false
        /*if ssl {
            /// if using ssl, try to connect with http/2 first
            /// it will fallback to http/1 automatically
            return HTTP2Client.connect(
                to: req.http.uri.hostname ?? "",
                port: req.http.uri.port,
                settings: HTTP2Settings(),
                on: req.Worker
            ).then { client in
                return client.send(request: req.http).then { httpRes -> Response in
                    let res = req.makeResponse()
                    res.http = httpRes
                    return res
                }
            }
        } else {*/
            /// if using cleartext, just use http/1.

        if ssl {
            #if os(macOS)
                return Future {
                    let tcpSocket = try TCPSocket(isNonBlocking: true)
                    let tcpClient = try TCPClient(socket: tcpSocket)
                    let tlsClient = try AppleTLSClient(tcp: tcpClient, using: TLSClientSettings())
                    try tlsClient.connect(hostname: req.http.uri.hostname!, port: req.http.uri.port ?? 443)
                    let client = HTTPClient(
                        stream: tlsClient.socket.stream(on: self.container),
                        on: self.container,
                        maxResponseSize: self.config.maxResponseSize
                    )
                    req.http.headers[.host] = req.http.uri.hostname
                    return client.send(req.http).map(to: Response.self) { httpRes in
                        let res = req.makeResponse()
                        res.http = httpRes
                        return res
                    }
                }
            #else
                fatalError("HTTPS not yet supported")
            #endif
        } else {
            return Future {
                let tcpSocket = try TCPSocket(isNonBlocking: true)
                let tcpClient = try TCPClient(socket: tcpSocket)
                try tcpClient.connect(hostname: req.http.uri.hostname!, port: req.http.uri.port ?? 80)
                let client = HTTPClient(
                    stream: tcpSocket.stream(on: self.container),
                    on: self.container,
                    maxResponseSize: self.config.maxResponseSize
                )
                req.http.headers[.host] = req.http.uri.hostname
                return client.send(req.http).map(to: Response.self) { httpRes in
                    let res = req.makeResponse()
                    res.http = httpRes
                    return res
                }
            }
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
