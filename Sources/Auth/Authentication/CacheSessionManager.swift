import Turnstile
import Random
import Cache

public final class CacheSessionManager: SessionManager {
    private let cache: CacheProtocol
    var turnstile: Turnstile! // FIXME

    public init(cache: CacheProtocol, turnstile: Turnstile?) {
        self.cache = cache
        self.turnstile = turnstile
    }

    /**
        Gets the user for the current session identifier.
    */
    public func getSubject(identifier: String) throws -> Subject {
        guard let id = try cache.get(identifier) else {
            throw AuthError.invalidIdentifier
        }

        let subject = Subject(turnstile: turnstile)
        try subject.login(credentials: Identifier(id: id))

        return subject
    }

    /**
        Creates a session for a given Subject object and returns the identifier.
    */
    public func createSession(user: Subject) -> String {
        let identifier = CryptoRandom.bytes(16).base64String

        // FIXME: authDetails not available yet
        if let id = user.authDetails?.account.uniqueID {
            try? cache.set(identifier, id)
        }

        return identifier
    }

    /**
        Destroys the session for a session identifier.
    */
    public func destroySession(identifier: String) {
        try! cache.delete(identifier)
    }
}
