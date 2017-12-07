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
        ).then { client in
            return client.send(request: req.http).then { httpRes -> Response in
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
        let port = port ?? (ssl ? 443 : 80)

        do {
            if ssl {
                let client = try container.make(BasicTLSClient.self, for: HTTPClient.self)

                return try client.connect(hostname: hostname, port: port).map {
                    return HTTPClient(socket: client)
                }
            } else {
                let client = try TCPClient(on: container)
                try client.connect(hostname: hostname, port: port)
                return Future(HTTPClient(socket: client))
            }
        } catch {
            return Future(error: error)
        }
    }
}
