import HTTP

@_exported import Routing

extension Droplet: RouteBuilder {
    public func register(host: String?, method: Method, path: [String], responder: Responder) {
        try! router().register(host: host, method: method, path: path, responder: responder)
    }
}

extension Int {
    public init?(_ string: String) {
        guard let int = string.int else {
            return nil
        }
        self = int
    }
}

extension Droplet {
    public func router() throws -> RouterProtocol {
        return try make()
    }
}

extension Router: RouterProtocol { }

// MARK: Service

extension Router: Service {
    /// See Service.name
    public static var name: String {
        return "branch"
    }

    /// See Service.make
    public static func make(for drop: Droplet) throws -> Self? {
        return .init()
    }
}
