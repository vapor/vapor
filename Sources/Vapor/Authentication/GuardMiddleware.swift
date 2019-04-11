/// This middleware ensures that an `Authenticatable` type `A` has been authenticated
/// by a previous `Middleware` or throws an `Error`. The middlewares that actually perform
/// authentication will _not_ throw errors if they fail to authenticate the user (except in
/// some exceptional cases like malformed data). This allows the middlewares to be composed
/// together to create chains of authentication for multiple user types.
///
/// Use this middleware to protect routes that might not otherwise attempt to access the
/// authenticated user (which always requires prior authentication).
///
/// Use `Authenticatable.guardAuthMiddleware(...)` to create an instance.
///
/// Use this middleware in conjunction with other middleware such as `BearerAuthenticationMiddleware`
/// and `BasicAuthenticationMiddleware` to do the actual authentication.
public final class GuardAuthenticationMiddleware<A>: Middleware
    where A: Authenticatable
{
    /// Error to throw when guard fails.
    private let error: Error

    /// Creates a new `GuardAuthenticationMiddleware`.
    ///
    /// - parameters:
    ///     - type: `Authenticatable` type to ensure is authed.
    ///     - error: `Error` to throw if the type is not authed.
    internal init(_ type: A.Type = A.self, throwing error: Error) {
        self.error = error
    }

    /// See `Middleware`.
    public func respond(to req: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard req.isAuthenticated(A.self) else {
            return req.eventLoop.makeFailedFuture(self.error)
        }
        return next.respond(to: req)
    }
}


extension Authenticatable {
    /// Creates a new `GuardAuthenticationMiddleware` for self.
    ///
    /// - parameters:
    ///     - error: `Error` to throw if the type is not authed.
    public static func guardAuthMiddleware(
        throwing error: Error = Abort(.unauthorized, reason: "\(Self.self) not authenticated.")
    ) -> GuardAuthenticationMiddleware<Self> {
        return .init(throwing: error)
    }
}
