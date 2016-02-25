
/**
 The route class that will be used to model the various paths
 the application can take
 */
public class Route {
    
    /**
     The responder type that is used when a route is matched
     */
    public typealias Handler = Request throws -> ResponseConvertible

    // MARK: Internal State
    
    internal static var scopedHost: String?
    internal static var scopedMiddleware: [Middleware.Type] = []
    internal static var scopedPrefix: String?

    // MARK: Attributes
    
    let method: Request.Method
    let path: String
    let handler: Request.Handler
    let hostname: String
    
    /**
     Designated Initializer
     
     - parameter method: Http Method associated with Route
     - parameter path: the path to use when deciding the route
     - parameter handler: the handler to route when the path is called
     */
    init(host: String = "*", method: Request.Method, path: String, handler: Request.Handler) {
        self.hostname = host
        self.method = method
        self.path = path
        self.handler = handler
    }
}

extension Route: CustomStringConvertible {
    public var description: String {
        return "\(self.method) \(self.path) \(self.hostname)"
    }
}