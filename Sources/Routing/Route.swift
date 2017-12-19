import HTTP
import Service

/// A route. When registered to a router, replies to `Request`s using the `Responder`.
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/route/)
public final class Route<Output>: Extendable {
    /// The path at which the route is assigned
    public var path: [PathComponent]
    
    /// The responder. Used to respond to a `Request`
    public var output: Output
    
    /// A storage place to extend the `Route` with.
    /// Can store metadata like Documentation/Route descriptions
    public var extend = Extend()
    
    /// Creates a new route from a Method, path and responder
    public init(path: [PathComponent], output: Output) {
        self.path = path
        self.output = output
    }
}
