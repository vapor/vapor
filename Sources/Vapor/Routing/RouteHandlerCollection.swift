import Routing

/// A RouteHandlerCollection is a type that defines a group of route handlers that rely on the `make(_:)` method on
/// `Request` objects for creating services to access data outside of the individual requests.
///
/// They can be conveniently registered to a `Router` using the `register(_:)` method as such:
///
///     router.register(MyRouteCollection.self)
///
/// In the `boot(on:)` method, you can create new groupings of routes on the incoming router object before registering
/// request handlers or use it as provided.
public protocol RouteHandlerCollection {
    /// Configure and register routes to the provided `Router`.
    ///
    ///     // create a group before registering
    ///     router.group("/users") { group in
    ///         group.get(use: getAllHandler)
    ///         group.get(User.parameter, use: getHandler)
    ///         // etc.
    ///     }
    ///
    ///     // Or don't
    ///     router.get(use: getAllHandler)
    ///     router.get(Int.parameter, use: getHandler)
    ///
    /// - SeeAlso: `Router` class for more details.
    static func boot(on router: Router) throws
}

extension Router {
    /// Calls the `RouteHandlerCollection.boot(on:)` hook to allow the provided type to manage how its route handlers
    /// are registered to this instance.
    public func register(_ collection: RouteHandlerCollection.Type) throws {
        try collection.boot(on: self)
    }
}
