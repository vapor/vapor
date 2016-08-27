import HTTP

extension Request {
    public func authenticated() throws -> User {
        let subject = try self.subject()

        guard let details = subject.authDetails else {
            throw AuthError.notAuthenticated
        }

        guard let user = details.account as? User else {
            throw AuthError.invalidAccountType
        }

        return user
    }
}
