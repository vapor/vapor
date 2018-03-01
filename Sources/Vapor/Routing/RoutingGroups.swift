//import HTTP
import Routing

extension Router {
    // MARK: - Create new group

    /// Creates a group cascading to router or group with the provided path components
    ///
    ///
    /// **Example:**
    /// ```
    /// // creating new group on router
    /// let users = router.grouped("user")
    ///
    /// // adding "user/auth/" route to router
    /// users.get("auth", use: userAuthHandler)
    ///
    /// // adding "user/profile/" route to router
    /// users.get("profile", use: userProfileHandler)
    ///
    /// ```
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    ///
    /// - Parameter path: Group path components separated by commas
    /// - Returns: created RouteGroup
    public func grouped(_ path: PathComponent...) -> Router {
        return RouteGroup(cascadingTo: self, components: path)
    }


    /// Creates a group cascading to router or group with the provided path components
    /// and use `configure` closure to configure crated group
    ///
    /// **Example:**
    /// ```
    /// // create new group and adds on router
    /// router.group(with: "user") { group in
    ///     // adding "user/auth/" route to router
    ///     group.get("auth", use: userAuthHandler)
    ///
    ///     // adding "user/profile/" route to router
    ///     group.get("profile", use: userProfileHandler)
    /// }
    ///
    /// ```
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    ///
    /// - Parameter path: Group path components separated by commas
    /// - Returns: created RouteGroup
    public func group(_ path: PathComponent..., configure: (Router) -> ()) {
        configure(RouteGroup(cascadingTo: self, components: path))
    }


    // MARK: - Add using of middleware

    /// Returns a RouteGroup cascading to router with middleware attached
    ///
    /// **Example:**
    /// ```
    /// let userMustBeAuthorized = AuthorizationMiddleware(....)
    /// let userMustBeCurrentUser = CheckIfCurrentUserMiddleware(....)
    ///
    /// // then creating new group on router
    /// let users = router.grouped("user")
    ///     .grouped(using: userMustBeAuthorized)
    ///     .grouped(using: userMustBeCurrentUser)
    ///
    /// // adding "user/profile/" route to router
    /// // both of validations applied
    /// users.get("profile", use: userProfileHandler)
    ///
    /// ```
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    ///
    /// - Parameter middleware: Middleware
    /// - Returns: RouterGroup with middleware attached
    public func grouped(_ middleware: [Middleware]) -> Router {
        return RouteGroup(cascadingTo: self, middleware: middleware)
    }


    /// Returns a RouteGroup cascading to router with middleware attached
    ///
    /// **Example:**
    /// ```
    /// let userMustBeAuthorized = AuthorizationMiddleware()
    ///
    /// // creating new group on router
    /// router.group(using: userMustBeAuthorized) { group in
    ///
    ///         // adding "user/profile/" route to router
    ///         // AuthorizationMiddleware is applied
    ///         group.get("profile", use: userProfileHandler)
    ///     }
    /// ```
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    /// - Parameters:
    ///   - middleware: Middleware
    ///   - configure: Group configuration function
    ///
    public func group(_ middleware: [Middleware], configure: (Router) -> ()) {
        configure(RouteGroup(cascadingTo: self, middleware: middleware))
    }

    // MARK: - Add using of middleware

    /// Returns a RouteGroup cascading to router with middleware attached
    ///
    /// **Example:**
    /// ```
    /// let userMustBeAuthorized = AuthorizationMiddleware(....)
    /// let userMustBeCurrentUser = CheckIfCurrentUserMiddleware(....)
    ///
    /// // then creating new group on router
    /// let users = router.grouped("user")
    ///     .grouped(using: userMustBeAuthorized)
    ///     .grouped(using: userMustBeCurrentUser)
    ///
    /// // adding "user/profile/" route to router
    /// // both of validations applied
    /// users.get("profile", use: userProfileHandler)
    ///
    /// ```
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    ///
    /// - Parameter middleware: Middleware
    /// - Returns: RouterGroup with middleware attached
    public func grouped(_ middleware: Middleware...) -> Router {
        return grouped(middleware)
    }


    /// Returns a RouteGroup cascading to router with middleware attached
    ///
    /// **Example:**
    /// ```
    /// let userMustBeAuthorized = AuthorizationMiddleware()
    ///
    /// // creating new group on router
    /// router.group(using: userMustBeAuthorized) { group in
    ///
    ///         // adding "user/profile/" route to router
    ///         // AuthorizationMiddleware is applied
    ///         group.get("profile", use: userProfileHandler)
    ///     }
    /// ```
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    /// - Parameters:
    ///   - middleware: Middleware
    ///   - configure: Group configuration function
    ///
    public func group(_ middleware: Middleware..., configure: (Router) -> ()) {
        return group(middleware, configure: configure)
    }
}

/// Groups routes
///
/// Every route will have the properties of this Group added
///
/// All path components will be inserted before the Route's path
///
/// All middleware will be applied to the Responder
///
/// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/)
fileprivate final class RouteGroup: Router {
    /// All routes registered to this group
    private(set) var routes: [Route<Responder>] = []

    let `super`: Router
    let components: [PathComponent]
    let middleware: [Middleware]
    
    /// Creates a new group
    ///
    /// All path components will be inserted before the Route's path
    ///
    /// All middleware will be applied to the Responder
    init(cascadingTo router: Router, components: [PathComponent] = [], middleware: [Middleware] = []) {
        self.super = router
        self.components = components
        self.middleware = middleware
    }
    
    /// Registers a route to this `Group`.
    ///
    /// Warning: Will modify the route
    func register(route: Route<Responder>) {
        self.routes.append(route)
        // Right after the method
        route.path.insert(contentsOf: self.components, at: 1)
        route.output = middleware.makeResponder(chainedto: route.output)
        self.super.register(route: route)
    }
    
    /// Routes a request, this feature should not be used normally
    func route(request: Request) -> Responder? {
        return self.super.route(request: request)
    }
}
