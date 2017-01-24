public enum AuthError: Swift.Error {
    case noSubject
    case invalidAccountType
    case invalidBasicAuthorization
    case invalidBearerAuthorization
    case noAuthorizationHeader
    case notAuthenticated
    case invalidIdentifier
    case invalidCredentials
    case unsupportedCredentials
}
