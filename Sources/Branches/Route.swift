import protocol Engine.HTTPResponseRepresentable
import class Engine.HTTPRequest
import protocol Engine.HTTPResponder
import enum Engine.HTTPMethod

/**
 The route class that will be used to model the various paths
 the droplet can take
 */
public struct Route<Output> {

    // MARK: Attributes

    public let host: String
    public let method: HTTPMethod
    public let path: String
    public let output: Output

    /**
     Designated Initializer

     - parameter method: Http Method associated with Route
     - parameter path: the path to use when deciding the route
     - parameter handler: the handler to route when the path is called
     */
    public init(host: String = "*", method: HTTPMethod = .get, path: String = "/", output: Output) {
        self.host = host
        self.method = method
        self.path = path
        self.output = output
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
            output: route.output
        )
    }
}
