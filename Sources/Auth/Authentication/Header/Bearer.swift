import Turnstile

extension Authorization {
	public func bearer() throws -> AccessToken {
        guard let range = header.range(of: "Bearer ") else {
            throw AuthError.invalidBearerAuthorization
        }

        let token = header.substring(from: range.upperBound)
        return AccessToken(string: token)
    }
}
