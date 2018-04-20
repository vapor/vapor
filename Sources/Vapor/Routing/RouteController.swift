import Routing

/// RouteCollection conformance provides a convenient way of organizing registration of a group of request handlers from
/// a controller instance onto `Router` objects.
///
///     router.register(MyRouteCollection.self)
///
/// In the `boot(on:)` method, you can create new groupings of routes on the incoming router object before registering
/// request handlers or use it as provided.
@available(*, deprecated, renamed: "RouteController")
public typealias RouteCollection = RouteController

/// RouteController conformance provides a convenient way of organizing registration of a group of request handlers from
/// a controller instance onto `Router` objects.
///
///     router.register(MyRouteController.self)
///
/// In the `boot(on:)` method, you can create new groupings of routes on the incoming router object before registering
/// request handlers or use it as provided.
public protocol RouteController {
    /// Configure and register routes to the provided `Router`.
    ///
    ///     // create a group before registering
    ///     router.group("/users") { group in
    ///         group.get(use: getAllHandler)
    ///         group.get(User.parameter, use: getHandler)
    ///         // etc.
    ///     }
    ///
    ///     // or don't
    ///     router.get(use: getAllHandler)
    ///     router.get(Int.parameter, use: getHandler)
    ///
    /// - SeeAlso: `Router` class for more details.
    @available(*, deprecated, renamed: "boot(on:)")
    func boot(router: Router) throws

    /// Configure and register routes to the provided `Router`.
    ///
    ///     // create a group before registering
    ///     router.group("/users") { group in
    ///         group.get(use: getAllHandler)
    ///         group.get(User.parameter, use: getHandler)
    ///         // etc.
    ///     }
    ///
    ///     // or don't
    ///     router.get(use: getAllHandler)
    ///     router.get(Int.parameter, use: getHandler)
    ///
    /// - SeeAlso: `Router` class for more details.
    func boot(on router: Router) throws
}

extension Router {
    /// Calls `RouteCollection.boot(router:)` to allow the provided object to manage how its route handlers are registered to
    /// this instance.
    @available(*, deprecated, renamed: "register(_:)")
    public func register(collection: RouteCollection) throws {
        try collection.boot(router: self)
    }

    /// Calls the `RouteController.boot(on:)` hook to allow the provided object to manage how its route handlers are
    /// registered to this instance.
    public func register(_ controller: RouteController) throws {
        try controller.boot(on: self)
    }
}
