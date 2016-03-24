import libc

/**
    Hash strings using the static methods on this class.
*/
public class Hash {
    
    /**
        The `applicationKey` adds an additional layer
        of security to all hashes. 
        
        Ensure this key stays
        the same during the lifetime of your application, since
        changing it will result in mismatching hashes.
    */
    public static var applicationKey: String = ""

    /**
        Any class that conforms to the `HashDriver` 
        protocol may be set as the `Hash`'s driver.
        It will be used to create the hashes 
        request by functions like `make()`
    */
    public static var driver: HashDriver = SHA256Hasher()
    
    /**
        Hashes a string using the `Hash` class's 
        current `HashDriver` and `applicationString` salt.
        
        - returns: Hashed string
    */
    public class func make(string: String) -> String {
        return Hash.driver.hash(string, key: applicationKey)
    }
    
}

