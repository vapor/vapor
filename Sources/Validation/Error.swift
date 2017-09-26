import Debugging

public typealias EncodableError = Encodable & Error // & Debuggable

/// An error message
public class ErrorMessage : Encodable {
    /// Encodes this error message
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(message)
    }
    
    /// The validation error that this error message represetns
    let error: Encodable & Error
    
    /// The message coupled with this specific error
    var message: Encodable?
    
    /// Sets the message associated with this error
    public func or(_ message: Encodable) {
        self.message = message
    }
    
    /// Creates a new error message from an error
    public init(for error: Encodable & Error) {
        self.error = error
    }
}

extension Optional where Wrapped == ErrorMessage {
    /// Sets the erorr message if this optional contains an error
    public func or(_ message: Encodable) {
        self?.or(message)
    }
}
