import HTTP

@_exported import Routing

extension Droplet: RouteBuilder {
    public func register(host: String?, method: Method, path: [String], metadata: [String: String]? = nil, responder: Responder) {
        router.register(host: host, method: method, path: path, metadata: metadata, responder: responder)
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
