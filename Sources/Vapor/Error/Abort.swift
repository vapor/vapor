import Core
import Debugging

/// Errors conforming to this protocol will always be displayed by
/// Vapor to the end-user (even in production mode where most errors are silenced).
public protocol AbortError: Debuggable {
    /// The HTTP status code this error will return.
    var status: HTTPResponseStatus { get }

    /// The human-readable (and hopefully understandable)
    /// reason for this error.
    var reason: String { get }
}

/// Simple abort error.
/// Note: we recommend creating your own error
/// types that conform to `AbortError` and use this
/// error type minimally.
public struct Abort: AbortError {
    /// See Debuggable.identifier
    public var identifier: String

    /// See AbortError.status
    public var status: HTTPResponseStatus

    /// See AbortError.reason
    public var reason: String

    /// See Traceable.file
    public var file: String

    /// See Traceable.function
    public var function: String

    /// See Traceable.line
    public var line: UInt

    /// See Traceable.column
    public var column: UInt

    /// See Traceable.stackTrace
    public var stackTrace: [String]

    /// Create a new abort error.
    public init(
        _ status: HTTPResponseStatus,
        reason: String? = nil,
        identifier: String? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.identifier = status.code.description
        self.status = status
        self.reason = reason ?? status.reasonPhrase
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.stackTrace = Abort.makeStackTrace()
    }
}

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
    var dotPath: String {
        return map { $0.stringValue }.joined(separator: ".")
    }
}
