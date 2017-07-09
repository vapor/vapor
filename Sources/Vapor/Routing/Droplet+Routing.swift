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

extension Router: Service {
    public convenience init?(_ drop: Droplet) throws {
        self.init()
    }
    
    public static var name: String {
        return "branch"
    }
}
