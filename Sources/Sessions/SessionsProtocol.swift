import Node

/**
    Session storage engines that conform to this
    protocol can be used to power the Session class.
*/
public protocol SessionsProtocol {
    /**
        Make a randomized session identifier

        - returns: a session identifier to use with a new session
    */
    func makeIdentifier() -> String

    /**
        Load the value at a specified key for a session with the given identifier

        - parameter key: the key to load value for
        - parameter identifier: the identifier of the session to get the key value for

        - returns: the value for given key, if exists
    */
    func get(for identifier: String) throws -> Session?

    /**
        Set a alue for the given key associated with a session of the given identifier

        - parameter value: value to set, nil if should remove
        - parameter key: key to set
        - parameter identifier: identifier of the session
    */
    func set(_ session: Session?, for identifier: String) throws

    /**
        Destroy the session associated with given identifier

        - parameter identifier: id of session
    */
    func destroy(_ identifier: String) throws

    /**
        Returns true if the Sessions contains
        an entry for the supplied identifier.
    */
    func contains(_ identifier: String) throws -> Bool
}

extension SessionsProtocol {
    public func destroy(_ identifier: String) throws {
        try set(nil, for: identifier)
    }

    public func contains(_ identifier: String) throws -> Bool {
        return try get(for: identifier) != nil
    }
}

public enum SessionsError: Error {
    case notConfigured
}
