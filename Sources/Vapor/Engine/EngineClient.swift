import Async
import HTTP
/*import HTTP2*/
import TCP
import TLS

/// HTTP/1.1 and HTTP/2 client wrapper.
public final class EngineClient: Client {
    /// See Client.container
    public let container: Container

    /// Create a new engine client
    public init(container: Container) {
        self.container = container
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
                on: req.eventLoop
            ).then { client in
                return client.send(request: req.http).then { httpRes -> Response in
                    let res = req.makeResponse()
                    res.http = httpRes
                    return res
                }
            }
        } else {*/
            /// if using cleartext, just use http/1.
        return HTTPClient.connect(
            to: req.http.uri.hostname ?? "",
            port: req.http.uri.port,
            ssl: ssl,
            using: req
        ).flatMap(to: Response.self) { client in
            req.http.headers[.host] = req.http.uri.hostname
            return client.send(request: req.http).map(to: Response.self) { httpRes in
                let res = req.makeResponse()
                res.http = httpRes
                return res
            }
        }
        /*}*/
    }
}

extension HTTPClient {
    /// Connects with HTTP/1.1 to a remote server.
    ///
    ///     // Future<HTTPClient>
    ///     let client = try HTTPClient.connect(
    ///        to: "example.com",
    ///        ssl: true,
    ///        worker: request
    ///     )
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/client/)
    public static func connect(to hostname: String, port: UInt16? = nil, ssl: Bool, using container: Container) -> Future<HTTPClient> {
        return then(to: HTTPClient.self) {
            let port = port ?? (ssl ? 443 : 80)
            
            if ssl {
                let client = try container.make(BasicSSLClient.self, for: HTTPClient.self)

                return try client.connect(hostname: hostname, port: port).map(to: HTTPClient.self) {
                    return HTTPClient(socket: client)
                }
            } else {
                let client = try TCPClient(on: container)
                
                return try client.connect(hostname: hostname, port: port).map(to: HTTPClient.self) {
                    return HTTPClient(socket: client)
                }
            }
        }
    }
}
