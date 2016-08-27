import Turnstile
import HTTP
import Middleware

public final class BasicAuthMiddleware: Middleware {
    public let turnstile: Turnstile

    public init(turnstile: Turnstile) {
        self.turnstile = turnstile
    }

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        let credentials = try request.authorization().basic()
        try request.user().login(credentials: credentials)

        return try next.respond(to: request)
    }
}
