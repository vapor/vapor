import HTTP
import Node

/**
    Represents errors that can be thrown in any Vapor closure.
    Then, these errors can be caught in `Middleware` to give a
    desired response.
 */
public protocol AbortError: Error {
    /// Textual representation on the error.
    var message: String { get }
    
    /// An integer representation of the error.
    var code: Int { get }
    
    /// The HTTP status code to return.
    var status: Status { get }
    
    /// `Optional` metadata.
    var metadata: Node? { get }
}

/**
    A handful of standard errors that can be thrown
    in any Vapor closure by calling `throw Abort.<case>`.
    These errors can be caught in Middleware to give
    a desired response.
*/
public enum Abort: Swift.Error {
    case badRequest
    case notFound
    case serverError
    case custom(status: Status, message: String)
}

extension Abort: AbortError {
    public var message: String {
        switch self {
        case .badRequest:
            return "Invalid request"
        case .notFound:
            return "Page not Found"
        case .serverError:
            return "Something went wrong"
        case .custom(status: _, message: let message):
            return message
        }
    }
    
    public var code: Int {
        switch self {
        case .badRequest:
            return 400
        case .notFound:
            return 404
        case .serverError:
            return 500
        case .custom(status: let status, message: _):
            return status.statusCode
        }
    }
    
    public var status: Status {
        switch self {
        case .badRequest:
            return .badRequest
        case .notFound:
            return .notFound
        case .serverError:
            return .internalServerError
        case .custom(status: let status, message: _):
            return status
        }
    }
    
    public var metadata: Node? {
        return nil
    }
}
