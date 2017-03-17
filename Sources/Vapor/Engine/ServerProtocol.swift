import HTTP
import TLS
import Transport

public enum SecurityLayer {
    case none
    case tls(TLS.Context)
}

public protocol ClientProtocol: Responder {
    init(hostname: String, port: Port, _ securityLayer: SecurityLayer) throws
}

public protocol ServerProtocol {
    init(hostname: String, port: Port, _ securityLayer: SecurityLayer) throws
    func start(_ responder: Responder) throws
}

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
        return Response()
    }
}

import URI

extension ClientProtocol {
    public static func respond(to req: Request) throws -> Response {
        let client = try Self.init(
            hostname: req.uri.hostname,
            port: req.uri.port ?? 80,
            .none
        )

        return try client.respond(to: req)
    }

    public static func request(_ method: Method, _ uri: String) throws  -> Response {
        let uri = try URI(uri)

        let request = Request(method: method, uri: uri)
        return try respond(to: request)
    }
}

public final class EngineServer: ServerProtocol {
    let server: Server

    public init(hostname: String, port: Transport.Port, _ securityLayer: SecurityLayer) throws {
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

private var _defaultTLSClientContext: () throws -> (TLS.Context) = {
    return try Context(.client)
}

extension ClientProtocol {
    public static var defaultTLSContext: () throws -> (TLS.Context) {
        get {
            return _defaultTLSClientContext
        }
        set {
            _defaultTLSClientContext = newValue
        }

    }
}

private var _defaultTLSServerContext: () throws -> (TLS.Context) = {
    return try Context(.server)
}

extension ServerProtocol {
    public static var defaultTLSContext: () throws -> (TLS.Context) {
        get {
            return _defaultTLSServerContext
        }
        set {
            _defaultTLSServerContext = newValue
        }

    }
}
