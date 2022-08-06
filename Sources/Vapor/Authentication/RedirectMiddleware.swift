extension Authenticatable {
    /// Basic middleware to redirect unauthenticated requests to the supplied path
    ///
    /// - parameters:
    ///    - path: The path to redirect to if the request is not authenticated

    public static func redirectMiddleware(path: String, appendNext: Bool = false) -> Middleware {
        self.redirectMiddleware(makePath: { req in path
            if appendNext {
                return "\(path)?next=\(req.url)"
            } else {
                return path
            }
        }, appendNext: appendNext)

    }

    /// Basic middleware to redirect unauthenticated requests to the supplied path
    ///
    /// - parameters:
    ///    - makePath: The closure that returns the redirect path based on the given `Request` object
    public static func redirectMiddleware(makePath: @escaping (Request) -> String, appendNext: Bool) -> Middleware {
        RedirectMiddleware<Self>(Self.self, makePath: makePath, appendNext: appendNext)
    }
}


private final class RedirectMiddleware<A>: Middleware
    where A: Authenticatable
{
    let makePath: (Request) -> String
    let appendNext: Bool

    init(_ authenticatableType: A.Type = A.self, makePath: @escaping (Request) -> String, appendNext: Bool) {
        self.makePath = makePath
        self.appendNext = appendNext
    }

    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        if request.auth.has(A.self) {
            return next.respond(to: request)
        }

        let redirect = request.redirect(to: self.makePath(request))
        return request.eventLoop.makeSucceededFuture(redirect)
    }
}
