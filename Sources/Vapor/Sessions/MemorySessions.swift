import Crypto

/// Simple in-memory sessions implementation.
public final class MemorySessions: Sessions {

    /// The internal storage.
    private var sessions: [String: Session]

    /// Generates a new cookie.
    public typealias CookieFactory = () -> (Cookie.Value)

    /// This middleware's cookie factory.
    private var cookieFactory: CookieFactory

    /// Create a new `MemorySessions` with the supplied cookie factory.
    public init(cookieFactory: @escaping CookieFactory) {
        self.cookieFactory = cookieFactory
        sessions = [:]
    }

    /// See Sessions.createSession
    public func createSession() throws -> Session {
        var cookie = cookieFactory()
        /// FIXME: optimize
        let random = Base64Encoder().encode(data: OSRandom().data(count: 16))
        cookie.value = String(data: random, encoding: .utf8)!
        return Session(from: cookie)
    }

    /// See Sessions.readSession
    public func readSession(for cookie: Cookie.Value) throws -> Session {
        guard let session = sessions[cookie.value] else {
            throw VaporError(identifier: "invalidSession", reason: "No session with that identifier was found.")
        }

        return session
    }

    /// See Sessions.updateSession
    public func updateSession(_ session: Session) {
        sessions[session.cookie.value] = session
    }

    /// See Sessions.destroySession
    public func destroySession(_ session: Session) throws {
        sessions[session.cookie.value] = nil
    }
}
