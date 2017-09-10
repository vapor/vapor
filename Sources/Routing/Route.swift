import HTTP
import Core

/// A route. When registered to a router, replies to `Request`s using the `Responder`.
public final class Route : Extendable {
    /// The path at which the route is assigned
    public var path: [PathComponent]
    
    /// The method that this route responds to
    public var method: Method
    
    /// The responder. Used to respond to a `Request`
    public var responder: Responder
    
    /// A storage place to extend the `Route` with.
    /// Can store metadata like Documentation/Route descriptions
    public var extend = Extend()
    
    /// Creates a new route from a Method, path and responder
    public init(method: Method, path: [PathComponent], responder: Responder) {
        self.method = method
        self.path = path
        self.responder = responder
    }
}
