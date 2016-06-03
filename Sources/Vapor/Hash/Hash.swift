import libc

/**
    Hash strings using the static methods on this class.
*/
public class Hash {

    private let key: String

    private let driver: HashDriver

    /**
        Initialize the Hash.

        - parameter key: a string used to add an additional layer of security to all hashes
        - parameter driver: instance of a class conforming to the HashDriver protocol,
                            defaulting to SHA2Hasher(.sha256), used to create hashes

        - warning: Ensure the key stays the same during the lifetime of your application,
                   since changing it will result in mismatching hashes.
    */
    public init(key: String? = nil, driver: HashDriver? = nil) {
        self.key = key ?? ""
        self.driver = driver ?? SHA2Hasher(variant: .sha256)
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
