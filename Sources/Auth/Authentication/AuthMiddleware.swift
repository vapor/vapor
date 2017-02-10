import Turnstile
import HTTP
import Cookies
import Foundation
import Cache

private let defaultCookieName = "vapor-auth"
private let cookieTimeout: TimeInterval = 7 * 24 * 60 * 60

public class AuthMiddleware<U: User>: Middleware {
    private let turnstile: Turnstile
    private let cookieName: String
    private let cookieFactory: CookieFactory

    public typealias CookieFactory = (String, String) -> Cookie

    public init(
        turnstile: Turnstile,
        cookieName: String = defaultCookieName,
        makeCookie cookieFactory: CookieFactory?
    ) {
        self.turnstile = turnstile
        
        self.cookieName = cookieName
        self.cookieFactory = cookieFactory ?? { name, value in
            return Cookie(
                name: name,
                value: value,
                expires: Date().addingTimeInterval(cookieTimeout),
                secure: false,
                httpOnly: true
            )
        }
    }

    public convenience init(
        user: U.Type = U.self,
        realm: Realm = AuthenticatorRealm(U.self),
        cache: CacheProtocol = MemoryCache(),
        cookieName: String = defaultCookieName,
        makeCookie cookieFactory: CookieFactory? = nil
    ) {
        let session = CacheSessionManager(cache: cache, realm: realm)
        let turnstile = Turnstile(sessionManager: session, realm: realm)
        self.init(turnstile: turnstile, cookieName: cookieName, makeCookie: cookieFactory)
    }

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        request.storage["subject"] = Subject(
            turnstile: turnstile,
            sessionID: request.cookies[cookieName]
        )

        let response = try next.respond(to: request)

        // If we have a new session, set a new cookie
        if
            let sid = try request.subject().sessionIdentifier,
            request.cookies[cookieName] != sid
        {
            let cookie = cookieFactory(cookieName, sid)
            response.cookies.insert(cookie)
        } else if
            try request.subject().sessionIdentifier == nil,
            request.cookies[cookieName] != nil
        {
            // If we have a cookie but no session, delete it.
            response.cookies[cookieName] = nil
        }

        return response
    }
}
