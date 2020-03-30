/// Capable of hashing a supplied password
public protocol PasswordHasher {
    func `for`(_ request: Request) -> PasswordHasher
    // Take a plaintext password and return a hashed password
    func hash(_ plaintext: String) throws -> String
}
