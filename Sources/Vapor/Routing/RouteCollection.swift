/// Groups collections of routes together for adding to a router.
#if compiler(>=6.0)
public protocol RouteCollection: Sendable {
    /// Registers routes to the incoming router.
    ///
    /// - parameters:
    ///     - routes: RoutesBuilder to register any new routes to.
    func boot(routes: RoutesBuilder) throws
}
#else
public protocol RouteCollection {
    /// Registers routes to the incoming router.
    ///
    /// - parameters:
    ///     - routes: `RoutesBuilder` to register any new routes to.
    func boot(routes: RoutesBuilder) throws
}
#endif

extension RoutesBuilder {
    /// Registers all of the routes in the group to this router.
    ///
    /// - parameters:
    ///     - collection: `RouteCollection` to register.
    public func register(collection: RouteCollection) throws {
        try collection.boot(routes: self)
    }
}
