extension Router {
    // MARK: Middleware Function
    
    /// Creates a sub `Router` wrapped in the supplied middleware function.
    ///
    ///     let group = router.grouped { req, next in
    ///         // this closure will be called with each request
    ///         print(req)
    ///         // use next responder in chain to respond
    ///         return try next.respond(to: req)
    ///     }
    ///     group.get("/") { ... }
    ///
    /// The above example logs all incoming requests.
    ///
    /// - parameters:
    ///     - respond: Closure accepting a `Request` and `Responder` and returning a `Future<Response>`.
    /// - returns: `Router` with closure attached
    public func grouped(_ respond: @escaping (Request, Responder) throws -> Future<Response>) -> Router {
        return grouped([MiddlewareFunction(respond)])
    }

    /// Creates a sub `Router` wrapped in the supplied middleware function.
    ///
    ///     router.group({ req, next in
    ///         // this closure will be called with each request
    ///         print(req)
    ///         // use next responder in chain to respond
    ///         return try next.respond(to: req)
    ///     }) { group in
    ///         group.get("/") { ... }
    ///     }
    ///
    /// The above example logs all incoming requests.
    ///
    /// - parameters:
    ///     - respond: Closure accepting a `Request` and `Responder` and returning a `Future<Response>`.
    ///     - configure: Closure to configure the newly created sub `Router`.
    public func group(_ respond: @escaping (Request, Responder) throws -> Future<Response>, configure: (Router) -> ()) {
        group([MiddlewareFunction(respond)], configure: configure)
    }
}

// MARK: Private

/// Wrapper to create Middleware from function
private class MiddlewareFunction: Middleware {
    /// Internal request handler.
    private let respond: (Request, Responder) throws -> Future<Response>

    /// Creates a new `MiddlewareFunction`
    init(_ function: @escaping (Request, Responder) throws -> Future<Response>) {
        self.respond = function
    }

    /// See `Middleware`.
    func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        return try self.respond(request, next)
    }
}
