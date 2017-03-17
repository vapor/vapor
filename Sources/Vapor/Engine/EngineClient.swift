import HTTP
import Transport
import Sockets
import TLS

public final class EngineClient: ClientProtocol {
    let client: Client

    public init(hostname: String, port: Port, _ securityLayer: SecurityLayer) throws {
        switch securityLayer {
        case .none:
            let socket = try TCPInternetSocket(
                scheme: "http",
                hostname: hostname,
                port: port
            )
            client = try TCPClient(socket)
        case .tls(let context):
            let socket = try TCPInternetSocket(
                scheme: "https",
                hostname: hostname,
                port: port
            )
            let tlsSocket = TLS.ClientSocket(socket, context)
            client = try TLSTCPClient(tlsSocket)
        }
    }

    public func respond(to request: Request) throws -> Response {
        return try client.respond(to: request)
    }
}
