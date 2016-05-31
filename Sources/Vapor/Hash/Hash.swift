import libc

/**
    Hash strings using the static methods on this class.
*/
public class Hash {

    /**
        The `key` adds an additional layer
        of security to all hashes.

        Ensure this key stays
        the same during the lifetime of your application, since
        changing it will result in mismatching hashes.
    */
    public var key: String = ""

    /**
        Any class that conforms to the `HashDriver`
        protocol may be set as the `Hash`'s driver.
        It will be used to create the hashes
        request by functions like `make()`
    */
    public var driver: HashDriver = SHA2Hasher(variant: .sha256)

    /**
        Initialize the Hash.
    */
    public init() {

    }

    /**
        Hashes a string using the `Hash` class's
        current `HashDriver` and `applicationString` salt.

        - returns: Hashed string
    */
    public func make(_ string: String) -> String {
        return driver.hash(string, key: key)
    }

}
