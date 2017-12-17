import Fluent
import Vapor

/// Protects a route group, requiring a password authenticatable
/// instance to pass through.
/// use `req.requireAuthenticated(A.self)` to fetch the instance.
public final class PasswordAuthenticationMiddleware<A>: Middleware
    where A: PasswordAuthenticatable
{
    /// the required password verifier
    public let verifier: PasswordVerifier

    /// The database identifier
    public let database: DatabaseIdentifier<A.Database>

    /// create a new password auth middleware
    public init(
        _ type: A.Type = A.self,
        verifier: PasswordVerifier,
        database: DatabaseIdentifier<A.Database>
    ) {
        self.verifier = verifier
        self.database = database
    }

    /// See Middleware.respond
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        // if the user has already been authenticated
        // by a previous middleware, continue
        if try req.isAuthenticated(A.self) {
            return try next.respond(to: req)
        }

        guard let password = req.http.headers.basicAuthorization else {
            throw AuthenticationError(
                identifier: "invalidCredentials",
                reason: "Basic authorization header required."
            )
        }

        // get database connection
        return req.connect(to: database).flatMap(to: Response.self) { conn in
            // auth user on connection
            return try A.authenticate(
                using: password,
                verifier: self.verifier,
                on: conn
            ).flatMap(to: Response.self) { a in
                // set authed on request
                try req.authenticate(a)
                return try next.respond(to: req)
            }
        }
    }
}
