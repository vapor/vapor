import HTTPTypes

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
public protocol AbortError: Error {
    /// The reason for this error.
    var reason: String { get }

    /// The HTTP status code this error will return.
    var status: HTTPResponse.Status { get }

    /// Optional `HTTPFields` to add to the error response.
    var headers: HTTPFields { get }
}

extension AbortError {
    /// See `AbortError`.
    public var headers: HTTPFields {
        [:]
    }

    /// See `AbortError`.
    public var reason: String {
        self.status.reasonPhrase
    }
}

extension AbortError where Self: DebuggableError {
    /// See `DebuggableError`.
    public var identifier: String {
        self.status.code.description
    }
}

// MARK: Default Conformances

/// Decoding errors are very common and should result in a 400 Bad Request response most of the time
extension DecodingError: AbortError {
    /// See `AbortError.status`
    public var status: HTTPResponse.Status {
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
        case let .dataCorrupted(ctx):       return "Data corrupted \(self.contextReason(ctx))"
        case let .keyNotFound(key, ctx):    return "No such key '\(key.stringValue)' \(self.contextReason(ctx))"
        case let .typeMismatch(type, ctx):  return "Value was not of type '\(type)' \(self.contextReason(ctx))"
        case let .valueNotFound(type, ctx): return "No value found (expected type '\(type)') \(self.contextReason(ctx))"
        @unknown default:                   return "Unknown error"
        }
    }
    
    private func contextReason(_ context: Context) -> String {
        "at path '\(context.codingPath.dotPath)'\(context.debugDescriptionAndUnderlyingError)"
    }
}

private extension DecodingError.Context {
    var debugDescriptionAndUnderlyingError: String {
        "\(self.debugDescriptionNoTrailingDot)\(self.underlyingErrorDescription)."
    }
    
    /// `debugDescription` sometimes has a trailing dot, and sometimes not.
    private var debugDescriptionNoTrailingDot: String {
        if self.debugDescription.isEmpty {
            return ""
        } else if self.debugDescription.last == "." {
            return ". \(self.debugDescription.dropLast())"
        } else {
            return ". \(self.debugDescription)"
        }
    }
    
    private var underlyingErrorDescription: String {
        self.underlyingError.map { ". Underlying error: \(String(describing: $0))" } ?? ""
    }
}
