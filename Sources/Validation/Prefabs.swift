import Foundation

// MARK: Email

fileprivate let name = "[a-z0-9!#$%&'*+/=?^_`{|}~]"
fileprivate let server = "[a-z0-9\\.-]"
fileprivate let pattern = "^\(name)+([\\.-]?\(name)+)*@\(server)+([\\.-]?\(server)+)*(\\.\\w\\w+)+$"

extension Validator {
    /// Asserts that the provided string is a valid email 
    @discardableResult
    public func assertEmail(_ email: String) -> ErrorMessage? {
        guard email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else {
            return assert(EmailValidationError(email: email))
        }
        
        return nil
    }
}

public struct EmailValidationError : EncodableError {
    public let email: String
}
