/// A basic username and password.
public struct Password {
    /// The username, sometimes an email address
    public let username: String

    /// The plaintext password
    public let password: String

    /// Create a new Password
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}
