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
    public let components: [PathComponent]
    public let middleware: [Middleware]
    
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
    
    /// Validation of `Request` than return `Response` wrapped in `Future` using `Responder`
    public typealias Validator  = (Request, Responder) throws -> Future<Response>
    
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
    
    /// Returns a group cascading to router with middleware attached
    ///
    ///
    /// **Example:**
    /// ```
    /// let userMustBeAuthorized = UserMustBeAuthorizedMiddleware(....)
    /// let currentUser = CheckIfCurrentUserMiddleware(....)
    ///
    /// // creating new group on router
    /// let users = router.group("user")
    ///   .validate(userMustBeAuthorized)
    ///   .validate(userMustBeCurrentUser)
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
    public func validate(_ middleware: Middleware...) -> RouteGroup {
        return RouteGroup(cascadingTo: self, middleware: middleware)
    }
    
    /// Returns a group cascading to router with validator attached
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
    ///   .validate(userMustBeAuthorized)
    ///   .validate(userMustBeCurrentUser)
    ///
    /// // adding "user/profile/" route to router
    /// // both of validations applied
    /// users.get("auth", use: userAuthHandler)
    ///
    /// ```
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    ///
    /// - Parameter validator: `(request: Request, next: Responder) throws -> Future<Response>`
    ///
    /// - Returns: RouterGroup with validator attached
    public func validate(_ validator: @escaping Validator) -> RouteGroup {
        return RouteGroup(cascadingTo: self, middleware: [MiddlewareFunction(validator)])
    }

}
