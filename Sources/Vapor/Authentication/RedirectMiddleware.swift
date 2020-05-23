extension Authenticatable {
    /// Basic middleware to redirect unauthenticated requests to the supplied path
    ///
    /// - parameters:
    ///    - path: The path to redirect to if the request is not authenticated
    public static func redirectMiddleware(path: String) -> Middleware {
        return RedirectMiddleware<Self>(Self.self, path: path)
    }
    
    /// Basic middleware to redirect unauthenticated requests to the supplied path
    ///
    /// - parameters:
    ///    - pathClosure: The closure that returns the redirect path based on the given URI path
    ///    - input: The original request path
    public static func redirectMiddleware(pathClosure: @escaping (_ input: String) -> String) -> Middleware {
        return RedirectMiddleware<Self>(Self.self, pathClosure: pathClosure)
    }
}


private final class RedirectMiddleware<A>: Middleware
    where A: Authenticatable
{
    let pathClosure: PathClosure
    
    typealias PathClosure = (String) -> String

    init(_ authenticatableType: A.Type = A.self, path: String) {
        self.pathClosure = { _ in return path }
    }
    
    init(_ authenticatableType: A.Type = A.self, pathClosure: @escaping PathClosure) {
        self.pathClosure = pathClosure
    }

    /// See Middleware.respond
    func respond(to req: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        if req.auth.has(A.self) {
            return next.respond(to: req)
        }
        
        let redirectPath = pathClosure(req.url.path)
        
        let redirect = req.redirect(to: redirectPath)
        return req.eventLoop.makeSucceededFuture(redirect)
    }
}
