/// Groups collections of routes together for adding to a router.
public protocol RouteCollection {
    /// Registers routes to the incoming router.
    ///
    /// - parameters:
    ///     - router: `Router` to register any new routes to.
    func boot(router: Router) throws
}

extension Router {
    /// Registers all of the routes in the group to this router.
    ///
    /// - parameters:
    ///     - collection: `RouteCollection` to register.
    public func register(collection: RouteCollection) throws {
        try collection.boot(router: self)
    }
}
