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
public protocol AbortError: Debuggable {
    /// The HTTP status code this error will return.
    var status: HTTPResponseStatus { get }

    /// The human-readable (and hopefully understandable) reason for this error.
    var reason: String { get }
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
        }
    }

    /// See `AbortError.reason`
    public var reason: String {
        switch self {
        case .dataCorrupted(let ctx): return ctx.debugDescription
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
        }
    }
}

extension Array where Element == CodingKey {
    fileprivate var dotPath: String {
        return map { $0.stringValue }.joined(separator: ".")
    }
}
