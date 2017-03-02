import Turnstile
import Random
import Cache

public final class CacheSessionManager: SessionManager {
    private let cache: CacheProtocol
    private let realm: Realm

    public init(cache: CacheProtocol, realm: Realm) {
        self.cache = cache
        self.realm = realm
    }

    /**
        Gets the user for the current session identifier.
    */
    public func restoreAccount(fromSessionID identifier: String) throws -> Account {
        guard let id = try cache.get(identifier) else {
            throw AuthError.invalidIdentifier
        }

        return try realm.authenticate(credentials: Identifier(id: id))
    }

    /**
        Creates a session for a given Subject object and returns the identifier.
    */
    public func createSession(account: Account) -> String {
        let identifier = try! CryptoRandom.bytes(count: 16).base64Encoded.string
        try? cache.set(identifier, account.uniqueID)
        return identifier
    }

    /**
        Destroys the session for a session identifier.
    */
    public func destroySession(identifier: String) {
        try? cache.delete(identifier)
    }
}
