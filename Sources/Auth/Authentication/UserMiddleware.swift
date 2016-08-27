import Turnstile
import HTTP
import Middleware
import Cookies
import Foundation

public class AuthMiddleware<U: User>: Middleware {
    private let turnstile: Turnstile

    public init(_ u: U.Type = U.self) {
        let s = MemorySessionManager()
        let r = DatabaseRealm(U.self)
        turnstile = Turnstile(sessionManager: s, realm: r)
    }

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {

        if
            let sessionIdentifier = request.cookies["TurnstileSession"],
            let subject = try? turnstile.sessionManager.getSubject(identifier: sessionIdentifier)
        {
            request.storage["auth:user"] = subject
        } else {
            request.storage["auth:user"] = Subject(turnstile: turnstile)
        }

        let response = try next.respond(to: request)

        // If we have a new session, set a new cookie
        if
            let sessionID = try request.user().authDetails?.sessionID,
            request.cookies["TurnstileSession"] != sessionID
        {
            let cookie = Cookie(
                name: "TurnstileSession",
                value: sessionID,
                expires: Date().addingTimeInterval(50000),
                secure: true,
                httpOnly: true
            )
            response.cookies.insert(cookie)
        } else if try request.user().authDetails?.sessionID == nil && request.cookies["TurnstileSession"] != nil {
            // If we have a cookie but no session, delete it.
            response.cookies["TurnstileSession"] = nil
        }

        return response
    }
}

public class ProtectMiddleware: Middleware {
    public init() {}
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        let user = try request.user()
        guard user.authenticated else {
            throw AuthError.notAuthenticated
        }

        return try next.respond(to: request)
    }
}
