import Turnstile
import Foundation
import Core

extension Authorization {
    public func basic() throws -> APIKey {
        guard let range = header.range(of: "Basic ") else {
            throw AuthError.invalidBasicAuthorization
        }

        let token = header.substring(from: range.upperBound)


        let decodedToken = token.base64DecodedString
        guard let separatorRange = decodedToken.range(of: ":") else {
            throw AuthError.invalidBasicAuthorization
        }

        let apiKeyID = decodedToken.substring(to: separatorRange.lowerBound)
        let apiKeySecret = decodedToken.substring(from: separatorRange.upperBound)

        return APIKey(id: apiKeyID, secret: apiKeySecret)
    }
}
