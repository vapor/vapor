import Turnstile
import HTTP
import Middleware
import Cookies
import Foundation
import Cache

public class AuthMiddleware<U: User>: Middleware {
    private let turnstile: Turnstile

    public init(
        user: U.Type = U.self,
        realm: Realm = AuthenticatorRealm(U.self),
        session: SessionManager = MemorySessionManager()
    ) {
        turnstile = Turnstile(sessionManager: session, realm: realm)
    }

    // FIXME
    /*public convenience init(
        user: U.Type = U.self,
        realm: Realm = AuthenticatorRealm(U.self),
        cache: CacheProtocol = MemoryCache()
    ) {
        let session = CacheSessionManager(cache: cache, turnstile: nil)
        turnstile = Turnstile(sessionManager: session, realm: realm)
    }*/

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        
        request.storage["subject"] = Subject(turnstile: turnstile, sessionID: request.cookies["TurnstileSession"])

        let response = try next.respond(to: request)

        // If we have a new session, set a new cookie
        if
            let sid = try request.subject().sessionIdentifier,
            request.cookies["TurnstileSession"] != sid
        {
            let cookie = Cookie(
                name: "TurnstileSession",
                value: sid,
                expires: Date().addingTimeInterval(50000),
                secure: false,
                httpOnly: true
            )
            response.cookies.insert(cookie)
        } else if
            try request.subject().sessionIdentifier == nil,
            request.cookies["TurnstileSession"] != nil
        {
            // If we have a cookie but no session, delete it.
            response.cookies["TurnstileSession"] = nil
        }

        return response
    }
}
