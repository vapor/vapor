import protocol Engine.ResponseRepresentable

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

    let method: Method
    let path: String
    let responder: Responder
    let hostname: String

    /**
        Designated Initializer

        - parameter method: Http Method associated with Route
        - parameter path: the path to use when deciding the route
        - parameter handler: the handler to route when the path is called
     */
    init(host: String = "*", method: Method, path: String, responder: Responder) {
        self.hostname = host
        self.method = method
        self.path = path
        self.responder = responder
    }

    init(host: String = "*", method: Method = .get, path: String = "/", closure: Request.Handler.Closure) {
        let responder = Request.Handler(closure)
        self.init(host: host, method: method, path: path, responder: responder)
    }
}

extension Route: CustomStringConvertible {
    public var description: String {
        return "\(self.method) \(self.path) \(self.hostname)"
    }
}
