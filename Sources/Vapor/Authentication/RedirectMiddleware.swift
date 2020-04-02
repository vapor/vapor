extension Authenticatable {
    /// Basic middleware to redirect unauthenticated requests to the supplied path
    ///
    /// - parameters:
    ///    - path: The path to redirect to if the request is not authenticated
    public static func redirectMiddleware(path: String) -> Middleware {
        return RedirectMiddleware<Self>(Self.self, path: path)
    }
}


private final class RedirectMiddleware<A>: Middleware
    where A: Authenticatable
{
    let path: String

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
