import Async
import Fluent

extension PasswordAuthenticatable {
    /// Authenticates using the supplied credentials, connection, and verifier.
    public static func authenticate(
        using password: Password,
        verifier: PasswordVerifier,
        on connection: DatabaseConnectable
    ) throws -> Future<Self> {
        return try Self
            .query(on: connection)
            .filter(usernameKey == password.username)
            .first()
            .map(to: Self.self)
        { user in
            guard let user = user else {
                throw AuthenticationError(
                    identifier: "invalidCredentials",
                    reason: "No \(Self.self) with matching credentials was found"
                )
            }

            guard try verifier.verify(
                password: password.password,
                matches: user.authPassword
            ) else {
                throw AuthenticationError(
                    identifier: "invalidCredentials",
                    reason: "No \(Self.self) with matching credentials was found"
                )
            }

            return user
        }
    }
}

