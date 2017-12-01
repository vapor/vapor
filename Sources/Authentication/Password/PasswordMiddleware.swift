import Vapor

public final class PasswordAuthenticationMiddleware<A>: Middleware
    where A: PasswordAuthenticatable
{
    /// the required password verifier
    public let verifier: PasswordVerifier

    /// create a new password auth middleware
    public init(
        _ type: A.Type = A.self,
        verifier: PasswordVerifier
    ) {
        self.verifier = verifier
    }

    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        // if the user has already been authenticated
        // by a previous middleware, continue
        if try req.isAuthenticated(A.self) {
            return try next.respond(to: req)
        }

        guard let password = req.http.headers.authorizationBasic else {
            throw AuthenticationError(
                identifier: "invalidCredentials",
                reason: "Basic authorization header required."
            )
        }

        // get database connection
        return req.connect(to: A.database).then { conn -> Future<Response> in
            // auth user on connection
            return try A.authenticate(
                using: password,
                verifier: self.verifier,
                on: conn
            ).then { a -> Future<Response> in
                // set authed on request
                try req.authenticate(a)
                return try next.respond(to: req)
            }
        }
    }
}
