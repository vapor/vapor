import Turnstile
import Foundation
import Core

@_exported import class Turnstile.APIKey

extension Authorization {
    public var basic: APIKey? {
        guard let range = header.range(of: "Basic ") else {
            return nil
        }

        let token = header.substring(from: range.upperBound)


        let decodedToken = token.bytes.base64Decoded.string
        guard let separatorRange = decodedToken.range(of: ":") else {
            return nil
        }

        let apiKeyID = decodedToken.substring(to: separatorRange.lowerBound)
        let apiKeySecret = decodedToken.substring(from: separatorRange.upperBound)

        return APIKey(id: apiKeyID, secret: apiKeySecret)
    }
}
