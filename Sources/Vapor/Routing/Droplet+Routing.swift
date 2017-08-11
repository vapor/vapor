import HTTP
import Routing
import Service

extension Droplet: RouteBuilder {
    public func register(host: String?, method: Method, path: [String], responder: Responder) {
        try! router().register(host: host, method: method, path: path, responder: responder)
    }
}

extension Int {
    public init?(_ string: String) {
        guard let int = Int(string) else {
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

extension Router: ServiceType {
    /// See Service.name
    public static var serviceName: String {
        return "branch"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [RouterProtocol.self]
    }

    /// See Service.make
    public static func makeService(for container: Container) throws -> Self? {
        return .init()
    }
}
