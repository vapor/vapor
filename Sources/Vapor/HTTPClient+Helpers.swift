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
    public static func connect(to uri: URI, worker: Worker) throws -> Future<HTTPClient> {
        let port = uri.port ?? uri.defaultPort ?? 80
        
        if uri.scheme == "https" {
            let client = try TLSClient(on: worker)
            
            return try client.connect(hostname: uri.hostname ?? "", port: port).map {_ in
                return HTTPClient(socket: client, worker: worker)
            }
        } else {
            let client = try TCPClient(worker: worker)
            
            return try client.connect(hostname: uri.hostname ?? "", port: port).map {
                client.start()
                
                return HTTPClient(socket: client, worker: worker)
            }
        }
    }
}
