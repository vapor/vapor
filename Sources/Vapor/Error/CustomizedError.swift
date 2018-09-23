/// Errors conforming to this protocol will always be displayed by
/// Vapor to the end-user (even in production mode where most errors are silenced).
///
///     extension MyError: CustomizedError { ... }
///     throw MyError(...)
///
/// See `CustomError` for a default implementation of this protocol.
///
///     throw CustomError(.badRequest, content: MyError(...))
///
public protocol CustomizedError: Error {
    
    /// The HTTP status code this error will return.
    var status: HTTPResponseStatus { get }
    
    /// Optional `HTTPHeaders` to add to the error response.
    var headers: HTTPHeaders { get }
    
    /// The model to be encoded in Response body
    var content: AnyEncodable { get }
}

extension CustomizedError {
    /// See `CustomError`.
    public var headers: HTTPHeaders {
        return [:]
    }
}

/// Default implementation of `CustomizedError`. You can use this as a convenient method for throwing
/// `CustomizedError`s without having to conform your own error-type to `CustomizedError`.
///     struct MyErrorFormat: Encodable {
///         let errorMessage: String
///         let reason: String
///     }
///     throw CustomError(.badRequest, content: MyErrorFormat(errorMessage: "User doesn't exist", reason: "Supplied ID is not a valid UUID"))
///
public struct CustomError: CustomizedError {
    /// See `CustomizedError`
    public var status: HTTPResponseStatus
    
    /// See `CustomizedError`
    public var headers: HTTPHeaders
    
    /// See `CustomizedError`
    public var content: AnyEncodable
    
    public init(status: HTTPResponseStatus, content: Encodable, headers: HTTPHeaders = [:]) {
        self.status = status
        self.content = AnyEncodable(content)
        self.headers = headers
    }
    
}


