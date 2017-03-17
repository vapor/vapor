import HTTP
import Transport
import Sockets
import TLS

public final class EngineServer: ServerProtocol {
    let server: Server

    public init(hostname: String, port: Port, _ securityLayer: SecurityLayer) throws {
        switch securityLayer {
        case .none:
            let socket = try TCPInternetSocket(
                scheme: "http",
                hostname: hostname,
                port: port
            )
            server = try TCPServer(socket)
        case .tls(let context):
            let socket = try TCPInternetSocket(
                scheme: "https",
                hostname: hostname,
                port: port
            )
            let tlsSocket = TLS.ServerSocket(socket, context)
            server = try TLSTCPServer(tlsSocket)
        }
    }

    public func start(_ responder: Responder) throws {
        try server.start(responder)
    }
}
