import HTTP
import Routing

/// Groups routes
///
/// Every route will have the properties of this Group added
///
/// All path components will be inserted before the Route's path
///
/// All middleware will be applied to the Responder
///
/// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/)
public final class RouteGroup: Router {
    /// All routes registered to this group
    public private(set) var routes: [Route<Responder>] = []
    
    let `super`: Router
    let components: [PathComponent]
    let middleware: [Middleware]
    
    /// Creates a new group
    ///
    /// All path components will be inserted before the Route's path
    ///
    /// All middleware will be applied to the Responder
    public init(cascadingTo router: Router, components: [PathComponent] = [], middleware: [Middleware] = []) {
        self.super = router
        self.components = components
        self.middleware = middleware
    }
    
    /// Registers a route to this `Group`.
    ///
    /// Warning: Will modify the route
    public func register(route: Route<Responder>) {
        self.routes.append(route)
        // Right after the method
        route.path.insert(contentsOf: self.components, at: 1)
        route.output = middleware.makeResponder(chainedto: route.output)
        self.super.register(route: route)
    }
    
    /// Routes a request, this feature should not be used normally
    public func route(request: Request) -> Responder? {
        return self.super.route(request: request)
    }
}

extension Router {
    
    // MARK: - Create new group
    
    /// Creates a group cascading to router or group with the provided path components
    ///
    ///
    /// **Example:**
    /// ```
    /// // creating new group on router
    /// let users = router.group("user")
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
    public func group(_ path: PathComponent...) -> RouteGroup {
        return RouteGroup(cascadingTo: self, components: path)
    }
    
    
    /// Creates a group cascading to router or group with the provided path components
    /// and use `configure` closure to configure crated group
    ///
    /// **Example:**
    /// ```
    /// // create new group and adds on router
    /// router.grouped(with: "user") { group in
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
    public func grouped(with path: PathComponent..., configure: (RouteGroup) -> ()) {
        configure(RouteGroup(cascadingTo: self, components: path))
    }
    
    
    // MARK: - Add using of middleware
    
    /// Returns a RouteGroup cascading to router with middleware attached
    ///
    /// **Example:**
    /// ```
    /// let userMustBeAuthorized = AuthorizationMiddleware(....)
    /// let currentUser = CheckIfCurrentUserMiddleware(....)
    ///
    /// // creating new group on router
    /// let users = router.group("user")
    ///     .using(AuthorizationMiddleware)
    ///     .using(userMustBeCurrentUser)
    ///
    /// // adding "user/profile/" route to router
    /// // both of validations applied
    /// users.get("auth", use: userAuthHandler)
    ///
    /// ```
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    ///
    /// - Parameter middleware: Middleware
    /// - Returns: RouterGroup with middleware attached
    public func using(_ middleware: Middleware...) -> RouteGroup {
        return RouteGroup(cascadingTo: self, middleware: middleware)
    }
    
    
    /// Returns a RouteGroup cascading to router with middleware attached
    ///
    /// **Example:**
    /// ```
    /// let userMustBeAuthorized = AuthorizationMiddleware()
    ///
    /// // creating new group on router
    /// router.using(AuthorizationMiddleware) { group in
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
    public func using(_ middleware: Middleware..., configure: (RouteGroup) -> ()) {
        configure(RouteGroup(cascadingTo: self, middleware: middleware))
    }
    
    // MARK: - Add using of middleware pure functions
    
    /// Returns a group cascading to router with function attached
    ///
    ///
    /// **Example:**
    /// ```
    /// let userMustBeAuthorized = { req, next in
    ///     return try userService.authorized(user)
    /// }
    ///
    /// let currentUser  = { req, next in
    ///     return try userService.isCurrentUser(req)
    /// }
    ///
    /// // creating new group on router
    /// let users = router.group("user")
    ///     .using(userMustBeAuthorized)
    ///     .using(userMustBeCurrentUser)
    ///
    /// // adding "user/profile/" route to router
    /// // both of validations applied
    /// users.get("auth", use: userAuthHandler)
    ///
    /// ```
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    ///
    /// - Parameter respond: `(request: Request, next: Responder) throws -> Future<Response>`
    ///
    /// - Returns: RouterGroup with closure attached
    public func using(_ respond: @escaping MiddlewareFunction.Respond) -> RouteGroup {
        return RouteGroup(cascadingTo: self, middleware: [MiddlewareFunction(respond)])
    }

    
    /// Ataches RouteGroup cascading to router with middleware attached
    /// and call configuaration function with new group provided
    /// **Example:**
    /// ```
    /// let userMustBeAuthorized = { req, next in
    ///     return try userService.authorized(user)
    /// }
    ///
    /// // creating new group on router
    /// router.using(userMustBeAuthorized) { group in
    ///
    ///         // adding "user/profile/" route to router
    ///         // AuthorizationMiddleware is applied
    ///         group.get("profile", use: userProfileHandler)
    ///     }
    /// ```
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    /// - Parameters:
    ///   - respond: respond: `(request: Request, next: Responder) throws -> Future<Response>`
    ///   - configure: Group configuration function
    ///
    public func use(_ respond: @escaping MiddlewareFunction.Respond, configure: (RouteGroup) -> ()) {
        configure(RouteGroup(cascadingTo: self, middleware: [MiddlewareFunction(respond)]))
    }
}
