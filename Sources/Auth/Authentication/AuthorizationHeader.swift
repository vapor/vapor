import Foundation
import Turnstile
import HTTP
import Core

public struct AuthorizationHeader {
    public let headerValue: String

    public init(_ value: String) {
        headerValue = value
    }

    public func basic() throws -> APIKey {
        guard let range = headerValue.range(of: "Basic ") else {
            throw AuthError.invalidBasicAuthorization
        }

        let token = headerValue.substring(from: range.upperBound)


        let decodedToken = token.base64DecodedString
        guard let separatorRange = decodedToken.range(of: ":") else {
            throw AuthError.invalidBasicAuthorization
        }

        let apiKeyID = decodedToken.substring(to: separatorRange.lowerBound)
        let apiKeySecret = decodedToken.substring(from: separatorRange.upperBound)

        return APIKey(id: apiKeyID, secret: apiKeySecret)
    }

    public func bearer() throws -> AccessToken {
        guard let range = headerValue.range(of: "Bearer ") else {
            throw AuthError.invalidBearerAuthorization
        }

        let token = headerValue.substring(from: range.upperBound)
        return AccessToken(string: token)
    }
}


extension Request {
    public func authorization() throws -> AuthorizationHeader {
        guard let authorization = headers["Authorization"] else {
            throw AuthError.noAuthorizationHeader
        }

        return AuthorizationHeader(authorization)
    }
}
