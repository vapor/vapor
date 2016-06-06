/**
    The route class that will be used to model the various paths
    the application can take
*/
public struct Route {

    /**
        The responder type that is used when a route is matched
     */
    public typealias Handler = (Request) throws -> ResponseRepresentable

    // MARK: Attributes

    let method: Request.Method
    let path: String
    let closure: (Request) throws -> Response
    let hostname: String

    /**
        Designated Initializer

        - parameter method: Http Method associated with Route
        - parameter path: the path to use when deciding the route
        - parameter handler: the handler to route when the path is called
     */
    init(host: String = "*", method: Request.Method, path: String, closure: (Request) throws -> Response) {
        self.hostname = host
        self.method = method
        self.path = path
        self.closure = closure
    }
}

extension Route: CustomStringConvertible {
    public var description: String {
        return "\(self.method) \(self.path) \(self.hostname)"
    }
}
