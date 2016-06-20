import libc

/**
    Hash strings using the static methods on this class.
*/
public protocol Hash: class {
    /**
        A string used to add an additional 
        layer of security to all hashes
    */
    var key: String { get set }

    /**
        Given a string, this function will
        return the hashed string according
        to whatever algorithm it chooses to implement.
    */
    func make(_ string: String) -> String
}
