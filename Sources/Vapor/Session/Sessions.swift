/**
    Session storage engines that conform to this
    protocol can be used to power the Session class.
*/
public protocol Sessions: class {
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
    func value(for key: String, identifier: String) -> String?

    /**
        Returns true if the session driver
        contains an entry for the given identifier.

        - parameter identifier: the identifier of the session
    */
    func contains(identifier: String) -> Bool

    /**
        Set a alue for the given key associated with a session of the given identifier

        - parameter value: value to set, nil if should remove
        - parameter key: key to set
        - parameter identifier: identifier of the session
     */
    func set(_ value: String?, for key: String, identifier: String)

    /**
        Destroy the session associated with given identifier

        - parameter identifier: id of session
     */
    func destroy(_ identifier: String)
}
