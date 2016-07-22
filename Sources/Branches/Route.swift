import protocol Engine.HTTPResponseRepresentable
import class Engine.HTTPRequest
import protocol Engine.HTTPResponder
import enum Engine.Method

/**
 The route class that will be used to model the various paths
 the droplet can take
 */
public struct Route<Output> {

    // MARK: Attributes

    public let host: String
    public let method: Method
    public let path: String
    public let handler: Output

    /**
     Designated Initializer

     - parameter method: Http Method associated with Route
     - parameter path: the path to use when deciding the route
     - parameter handler: the handler to route when the path is called
     */
    public init(host: String = "*", method: Method = .get, path: String = "/", responder: Output) {
        self.host = host
        self.method = method
        self.path = path
        self.handler = responder
    }
}

extension Route: CustomStringConvertible {
    public var description: String {
        return "\(method) \(host) \(path)"
    }
}

extension Router {
    @discardableResult
    public func register(_ route: Route<Output>) -> Branch<Output>{
        return register(
            host: route.host,
            method: route.method.description,
            path: route.path,
            output: route.handler
        )
    }
}
