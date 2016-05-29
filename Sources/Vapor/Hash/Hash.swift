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
    private let key: String

    /**
        Any class that conforms to the `HashDriver`
        protocol may be set as the `Hash`'s driver.
        It will be used to create the hashes
        request by functions like `make()`
    */
    private let driver: HashDriver

    /**
        Initialize the Hash.

        - parameter key: seed the hash with a secret key to add an additional layer of security to all hashes

        - parameter driver: an instance of any class that conforms to the `HashDriver` protocol, defaults to SHA2Hasher

        - warning: Ensure the `key` stays the same during the lifecycle of your application.
    */
    public init(key: String, driver: HashDriver = nil) {
        self.key = key
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
