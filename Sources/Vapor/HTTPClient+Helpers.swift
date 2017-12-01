import Async
import HTTP
import TCP
import TLS

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
    public static func connect(to hostname: String, port: UInt16? = nil, ssl: Bool, context: Context) throws -> Future<HTTPClient> {
        let port = port ?? (ssl ? 443 : 80)
        
        if ssl {
            let client = try TLSClient(on: context)
            
            return try client.connect(hostname: hostname, port: port).map {_ in
                return HTTPClient(context: context, socket: client)
            }
        } else {
            let client = try TCPClient(worker: context)
            
            return try client.connect(hostname: hostname, port: port).map {
                client.start()
                
                return HTTPClient(context: context, socket: client)
            }
        }
    }
}
