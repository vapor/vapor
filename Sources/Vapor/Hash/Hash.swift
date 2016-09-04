import libc

/**
    Hash strings using the static methods on this class.
*/
public protocol Hash: class {
    /**
         A string used to add an additional
         layer of security to all hashes
    */
    var defaultKey: String? { get }

    /**
         Given a string, this function will
         return the hashed string according
         to whatever algorithm it chooses to implement.
    */
    func make(_ string: String, key: String?) throws -> String
}

extension Hash {
    public var defaultKey: String? { return nil }

    public func make(_ string: String) throws -> String {
        return try make(string, key: defaultKey)
    }
}
