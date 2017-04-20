import Routing
import Core

/// Objects conforming to this protocol can be used
/// to add collections of rotues to a route builder.
public protocol RouteCollection {
    func build(_ builder: RouteBuilder) throws
}

extension RouteBuilder {
    /// Adds the collection of routes
    public func collection<C: RouteCollection>(_ c: C) throws {
        try c.build(self)
    }
    
    /// Adds the collection of routes
    public func collection<C: RouteCollection & EmptyInitializable>(_ c: C.Type) throws {
        let c = try C()
        try c.build(self)
    }
}
