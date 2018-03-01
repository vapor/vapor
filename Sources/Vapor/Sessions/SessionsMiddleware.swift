//import Foundation
//
///// Checks the cookies for each `Request`
//public final class SessionsMiddleware: Middleware, Service {
//    /// The cookie to work with
//    let cookieName: String
//    
//    /// Creates new cookies
//    public let sessions: Sessions
//    
//    /// Creates a new `SessionsMiddleware`.
//    public init(cookieName: String, sessions: Sessions) {
//        self.cookieName = cookieName
//        self.sessions = sessions
//    }
//    
//    /// See `Middleware.respond`
//    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
//        /// Create a session cache
//        let cache = try request.privateContainer.make(SessionCache.self, for: Request.self)
//        cache.middlewareFlag = true
//
//        /// Generate a response for the request
//        func respond() throws -> Future<Response> {
//            return try next.respond(to: request).flatMap(to: Response.self) { res in
//                if let session = cache.session {
//                    /// A session exists or has been created. we must
//                    /// set a cookie value on the response
//                    return try self.sessions.updateSession(session).map(to: Response.self) { value in
//                        res.http.cookies[self.cookieName] = value
//                        return res
//                    }
//                } else if let cookieValue = request.http.cookies[self.cookieName] {
//                    /// Yhe request had a session cookie, but now there is no session.
//                    /// we need to perform cleanup.
//                    return try self.sessions.destroySession(for: cookieValue).map(to: Response.self) {
//                        res.http.cookies[self.cookieName] = Cookie.Value(
//                            value: "",
//                            expires: Date(timeIntervalSince1970: 0),
//                            maxAge: nil,
//                            domain: nil,
//                            path: nil,
//                            secure: false,
//                            httpOnly: false,
//                            sameSite: nil
//                        )
//                        return res
//                    }
//                } else {
//                    /// no session or existing cookie
//                    return Future(res)
//                }
//            }
//        }
//
//        /// Check for an existing session
//        if let cookieValue = request.http.cookies[cookieName] {
//            /// A cookie value exists, get the session for it.
//            return try sessions.readSession(for: cookieValue).flatMap(to: Response.self) { session in
//                cache.session = session
//                return try respond()
//            }
//        } else {
//            /// No cookie value exists, simply respond.
//            return try respond()
//        }
//    }
//}
//
//extension SessionsMiddleware: ServiceType {
//    /// See `ServiceType.makeService(for:)`
//    public static func makeService(for container: Container) throws -> SessionsMiddleware {
//        let config = try container.make(SessionsConfig.self, for: SessionsMiddleware.self)
//        return try .init(
//            cookieName: config.cookieName,
//            sessions: container.make(for: SessionsMiddleware.self)
//        )
//    }
//}

