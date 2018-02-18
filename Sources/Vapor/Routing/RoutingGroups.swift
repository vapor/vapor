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
    public func grouped(_ path: PathComponent...) -> RouteGroup {
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
    public func group(with path: PathComponent..., configure: (RouteGroup) -> ()) {
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
    public func grouped(using middleware: Middleware...) -> RouteGroup {
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
    public func group(using middleware: Middleware..., configure: (RouteGroup) -> ()) {
        configure(RouteGroup(cascadingTo: self, middleware: middleware))
    }
    
    // MARK: - Add using of middleware pure functions
    
    /// Returns a group cascading to router with function attached
    ///
    ///
    /// **Example:**
    ///
    ///
    /// We can create some authorization closure to check whether user is authorized
    /// ```
    /// let userMustBeAuthorized = { req, next in
    ///     // User is the user model class which can parse request
    ///     // and returns User instance or nil
    ///     guard User(from: req) != nil else { throw AuthError.unauthorized }
    ///     return next.respond(to: request)
    /// }
    /// ```
    ///
    /// Then create new group on router
    /// ```
    /// let users = router.group("user")
    ///     .grouped(using: userMustBeAuthorized)
    /// ```
    ///
    /// And then users *group* will apply this closure to every request to check whether user is unauthorized or not
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    ///
    /// - Parameter respond: `(request: Request, next: Responder) throws -> Future<Response>`
    /// - Returns: RouterGroup with closure attached
    public func grouped(using respond: @escaping MiddlewareFunction.Respond) -> RouteGroup {
        return RouteGroup(cascadingTo: self, middleware: [MiddlewareFunction(respond)])
    }
    
    
    /// *Ataches RouteGroup cascading to router with function as a middleware attached*
    /// and call configuaration function with new group provided
    ///
    /// **Example:**
    ///
    /// First of all we need some function which implements authorization logic.
    /// Function must returns `Future<Response>` to not breaking chaining of middlewares
    /// It might be static or instance function, or just closure, it doesn't matter
    /// ```
    /// static func userMustBeAuthorized(request: Request, next: Responder) throws -> Future<Response> {
    ///     // User is the user model class which can parse request
    ///     // and returns User instance or nil
    ///     guard User(from: request) != nil else { throw AuthError.unauthorized }
    ///     return next.respond(to: request)
    /// }
    /// ```
    ///
    /// Then we pass function as a parameter
    /// ```
    /// router.group(using: userMustBeAuthorized) { group in
    ///     group.get("profile", use: userProfileHandler)
    /// }
    /// ```
    ///
    /// And this *router* will apply this function to every request to check whether user is unauthorized or not
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    /// - Parameters:
    ///   - respond: respond: `(request: Request, next: Responder) throws -> Future<Response>`
    ///   - configure: Group configuration function
    public func group(using respond: @escaping MiddlewareFunction.Respond, configure: (RouteGroup) -> ()) {
        configure(RouteGroup(cascadingTo: self, middleware: [MiddlewareFunction(respond)]))
    }
}

