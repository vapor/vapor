/**
    Classes that conform to `HashDriver` may be set
    as the `Hash` classes hashing engine.
*/
public protocol HashDriver {

    /**
        * Given a string, this function will 
        * return the hashed string according
        * to whatever algorithm it chooses to implement.
    */
    func hash(message: String, key: String) -> String
}
