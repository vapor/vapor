protocol Model { }

final class User: Model {
    /// The user's name
    let name: String

    /// The user's age
    let age: Int

    /// The user's hashed password
    /// - json: false
    let password: String

    /// Create a new user
    init(name: String, age: Int, password: String) {
        self.name = name
        self.age = age
        self.password = password
    }
}
