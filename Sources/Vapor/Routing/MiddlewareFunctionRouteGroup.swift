extension Router {
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
    ///     .grouped(userMustBeAuthorized)
    /// ```
    ///
    /// And then users *group* will apply this closure to every request to check whether user is unauthorized or not
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    ///
    /// - Parameter respond: `(request: Request, next: Responder) throws -> Future<Response>`
    /// - Returns: RouterGroup with closure attached
    public func grouped(_ respond: @escaping (Request, Responder) throws -> Future<Response>) -> Router {
        return grouped([MiddlewareFunction(respond)])
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
    public func group(_ respond: @escaping (Request, Responder) throws -> Future<Response>, configure: (Router) -> ()) {
        group([MiddlewareFunction(respond)], configure: configure)
    }
}

/// Wrapper to create Middleware from function
fileprivate class MiddlewareFunction: Middleware {
    /// Internal request handler.
    private let respond: (Request, Responder) throws -> Future<Response>

    /// Creates a new `MiddlewareFunction`
    init(_ function: @escaping (Request, Responder) throws -> Future<Response>) {
        self.respond = function
    }

    /// See `Middleware.respond(to:chainingTo:)`
    func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        return try self.respond(request,next)
    }
}
