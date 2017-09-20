import Async
import Dispatch
import HTTP
import TCP

public typealias HTTPClient = HTTP.Client

// MARK: Connect
extension HTTP.Client {
    /// Connects an `HTTP.Client` to an HTTP Server
    public static func connect(to uri: URI, on queue: DispatchQueue) throws -> HTTP.Client {
        guard
            uri.scheme == "http" || uri.scheme == "https",
            let hostname = uri.hostname,
            let port = uri.defaultPort ?? uri.port else {
                throw Error(identifier: "http-client-uri", reason: "The URI was invalid for connecting with an HTTP Client")
        }
        
        let socket = try TCP.Socket()
        try socket.connect(hostname: hostname, port: port)
        let tcp = TCP.Client(socket: socket, queue: queue)
        
        // TODO: TLS
        
        defer { tcp.start() }
        
        return HTTP.Client(tcp: tcp)
    }
}
