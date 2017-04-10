import HTTP
import Transport
import URI
import TLS

/// types conforming to this protocol can be 
/// set as the Droplet's `.client`
public protocol ClientFactory: Responder {
    func makeClient(
        hostname: String,
        port: Port,
        _ securityLayer: SecurityLayer
    ) throws -> Responder
}

extension ClientFactory {
    func makeClient(for req: Request, using s: SecurityLayer? = nil) throws -> Responder {
        // use security layer from input or
        // determine based on req uri scheme
        let securityLayer: SecurityLayer
        if let s = s {
            securityLayer = s
        } else if req.uri.scheme.isSecure {
            securityLayer = .tls(try EngineClientFactory.defaultTLSContext())
        } else {
            securityLayer = .none
        }
        
        return try makeClient(
            hostname: req.uri.hostname,
            port: req.uri.port ?? req.uri.scheme.port,
            securityLayer
        )
    }
}

// MARK: Convenience

extension String {
    var port: Port {
        return isSecure ? 443 : 80
    }
}

extension Responder {
    /// Creates a new client from the information in the 
    /// Request URI and uses it to respond to the request.
    public func respond(
        to req: Request,
        through middleware: [Middleware] = []
    ) throws -> Response {
        return try middleware
            .chain(to: self)
            .respond(to: req)
    }

    /// Creates a new client and calls `.respond()`
    /// using the request method and uri provided.
    public func request(
        _ method: Method,
        _ uri: String,
        query: [String: NodeRepresentable] = [:],
        _ headers: [HeaderKey: String] = [:],
        _ body: BodyRepresentable? = nil,
        through middleware: [Middleware] = []
    ) throws  -> Response {
        var uri = try URI(uri)

        var q: [String: CustomStringConvertible] = [:]
        try query.forEach { key, value in
            q[key] = try value.makeNode(in: nil).string ?? ""
        }
        uri.append(query: q)

        let req = Request(method: method, uri: uri)
        req.headers = headers


        if let body = body {
            req.body = body.makeBody()
        }
        return try respond(to: req, through: middleware)
    }
}

// MARK: TLS

private var _defaultTLSClientContext: () throws -> (TLS.Context) = {
    return try Context(.client)
}

extension ClientFactory {
    public static var defaultTLSContext: () throws -> (TLS.Context) {
        get {
            return _defaultTLSClientContext
        }
        set {
            _defaultTLSClientContext = newValue
        }

    }
}
