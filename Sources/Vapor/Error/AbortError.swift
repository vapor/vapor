/// Errors conforming to this protocol will always be displayed by
/// Vapor to the end-user (even in production mode where most errors are silenced).
///
///     extension MyError: AbortError { ... }
///     throw MyError(...) // Can now result in non-500 error.
///
/// See `Abort` for a default implementation of this protocol.
///
///     throw Abort(.badRequest, reason: "Something's not quite right...")
///
public protocol AbortError: LocalizedError, CustomStringConvertible {
    /// The HTTP status code this error will return.
    var status: HTTPResponseStatus { get }

    /// Optional `HTTPHeaders` to add to the error response.
    var headers: HTTPHeaders { get }

    /// The human-readable (and hopefully understandable) reason for this error.
    var reason: String { get }
    
    var source: ErrorSource? { get }
}

public struct ErrorSource {
    public let file: String
    public let line: UInt
    public let function: String
    
    public init(file: String = #file, line: UInt = #line, function: String = #function) {
        self.file = file
        self.line = line
        self.function = function
    }
}

extension AbortError {
    /// See `AbortError`.
    public var headers: HTTPHeaders {
        return [:]
    }

    public var errorDescription: String? {
        return self.description
    }
    
    public var source: ErrorSource? {
        return nil
    }
}

// MARK: Default Conformances

/// Decoding errors are very common and should result in a 400 Bad Request response most of the time
extension DecodingError: AbortError {
    /// See `AbortError.status`
    public var status: HTTPResponseStatus {
        return .badRequest
    }

    /// See `AbortError.identifier`
    public var identifier: String {
        switch self {
        case .dataCorrupted: return "dataCorrupted"
        case .keyNotFound: return "keyNotFound"
        case .typeMismatch: return "typeMismatch"
        case .valueNotFound: return "valueNotFound"
        @unknown default: return "unknown"
        }
    }
    
    /// See `CustomStringConvertible`.
    public var description: String {
        return "Decoding error: \(self.reason)"
    }

    /// See `AbortError.reason`
    public var reason: String {
        switch self {
        case .dataCorrupted(let ctx):
            return "\(ctx.debugDescription) for key \(ctx.codingPath.dotPath)"
        case .keyNotFound(let key, let ctx):
            let path: String
            if ctx.codingPath.count > 0 {
                path = ctx.codingPath.dotPath + "." + key.stringValue
            } else {
                path = key.stringValue
            }
            return "Value required for key '\(path)'."
        case .typeMismatch(let type, let ctx):
            return "Value of type '\(type)' required for key '\(ctx.codingPath.dotPath)'."
        case .valueNotFound(let type, let ctx):
            return "Value of type '\(type)' required for key '\(ctx.codingPath.dotPath)'."
        @unknown default: return "Unknown error."
        }
    }
}
