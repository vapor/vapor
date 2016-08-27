import Turnstile
import Foundation
import Core

extension Authorization {
    public var basic: APIKey? {
        guard let range = header.range(of: "Basic ") else {
            return nil
        }

        let token = header.substring(from: range.upperBound)


        let decodedToken = token.base64DecodedString
        guard let separatorRange = decodedToken.range(of: ":") else {
            return nil
        }

        let apiKeyID = decodedToken.substring(to: separatorRange.lowerBound)
        let apiKeySecret = decodedToken.substring(from: separatorRange.upperBound)

        return APIKey(id: apiKeyID, secret: apiKeySecret)
    }
}
