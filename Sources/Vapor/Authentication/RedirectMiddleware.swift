import NIOCore

extension Authenticatable {
    /// Basic middleware to redirect unauthenticated requests to the supplied path
    ///
    /// - parameters:
    ///    - path: The path to redirect to if the request is not authenticated
    public static func redirectMiddleware(path: String) -> any Middleware {
        self.redirectMiddleware(makePath: { _ in path })
    }
    
    /// Basic middleware to redirect unauthenticated requests to the supplied path
    ///
    /// - parameters:
    ///    - makePath: The closure that returns the redirect path based on the given `Request` object
    public static func redirectMiddleware(makePath: @Sendable @escaping (Request) -> String) -> any Middleware {
        RedirectMiddleware<Self>(Self.self, makePath: makePath)
    }
}


private final class RedirectMiddleware<A>: Middleware
    where A: Authenticatable
{
    let makePath: @Sendable (Request) -> String
    
    init(_ authenticatableType: A.Type = A.self, makePath: @Sendable @escaping (Request) -> String) {
        self.makePath = makePath
    }

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        if request.auth.has(A.self) {
            return try await next.respond(to: request)
        }

        return request.redirect(to: self.makePath(request))
    }
}
