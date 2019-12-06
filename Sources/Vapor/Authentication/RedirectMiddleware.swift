extension Authenticatable {
    /// Basic middleware to redirect unauthenticated requests to the supplied path
    public static func redirectMiddleware(path: String) -> Middleware {
        return RedirectMiddleware<Self>(Self.self, path: path)
    }
}


/// Basic middleware to redirect unauthenticated requests to the supplied path
private final class RedirectMiddleware<A>: Middleware where A: Authenticatable {
    /// The path to redirect to
    let path: String

    /// Initialise the `RedirectMiddleware`
    ///
    /// - parameters:
    ///    - authenticatableType: The type to check authentication against
    ///    - path: The path to redirect to if the request is not authenticated
    init(_ authenticatableType: A.Type = A.self, path: String) {
        self.path = path
    }

    /// See Middleware.respond
    func respond(to req: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        if req.auth.has(A.self) {
            return next.respond(to: req)
        }
        let redirect = req.redirect(to: path)
        return req.eventLoop.makeSucceededFuture(redirect)
    }
}
