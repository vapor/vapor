import Crypto
import Foundation

/// Simple in-memory sessions implementation.
public final class MemorySessions: Sessions {
    /// The internal storage.
    private var sessions: [String: Session]

    /// Generates a new cookie.
    /// Accepts the cookie's string value and returns an
    /// initialized cookie value.
    public typealias CookieFactory = (String) -> (Cookie.Value)

    /// This middleware's cookie factory.
    private var cookieFactory: CookieFactory

    /// MemorySession with basic cookie factory.
    public static func `default`() -> MemorySessions {
        return .init { value in
            return Cookie.Value(
                value: value,
                expires: Date(
                    timeIntervalSinceNow: 60 * 60 * 24 * 7 // one week
                ),
                maxAge: nil,
                domain: nil,
                path: "/",
                secure: false,
                httpOnly: false,
                sameSite: nil
            )
        }
    }

    /// Create a new `MemorySessions` with the supplied cookie factory.
    public init(cookieFactory: @escaping CookieFactory) {
        self.cookieFactory = cookieFactory
        sessions = [:]
    }

    /// See Sessions.readSession
    public func readSession(for cookie: Cookie.Value) throws -> Session? {
        return sessions[cookie.value]
    }

    /// See Sessions.destroySession
    public func destroySession(for cookie: Cookie.Value) throws {
        sessions[cookie.value] = nil
    }

    /// See Sessions.updateSession
    public func updateSession(_ session: Session) throws -> Cookie.Value {
        let cookie: Cookie.Value
        if let existing = session.cookie {
            cookie = existing
        } else {
            /// FIXME: optimize
            let random = Base64Encoder().encode(data: OSRandom().data(count: 16))
            cookie = cookieFactory(String(data: random, encoding: .utf8)!)
        }
        sessions[cookie.value] = session
        return cookie
    }
}
