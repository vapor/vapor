import HTTPTypes

/// Errors conforming to this protocol will always be displayed by
/// Vapor to the end-user (even in production mode where most errors are silenced).
///
///     extension MyError: AbortError { ... }
///     throw MyError(...) // Can now result in non-500 error.
///
/// See ``Abort`` for a default implementation of this protocol.
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
    // See `AbortError.headers`.
    public var headers: HTTPFields {
        [:]
    }

    // See `AbortError.reason`.
    public var reason: String {
        self.status.reasonPhrase
    }
}

extension AbortError where Self: DebuggableError {
    // See `DebuggableError.identifier`.
    public var identifier: String {
        self.status.code.description
    }
}

// MARK: Default Conformances

/// Decoding errors are very common and should result in a 400 Bad Request response most of the time
extension DecodingError: AbortError {
    // See `AbortError.status`
    public var status: HTTPResponse.Status {
        .badRequest
    }

    // See `AbortError.identifier`
    public var identifier: String {
        switch self {
        case .dataCorrupted: "dataCorrupted"
        case .keyNotFound: "keyNotFound"
        case .typeMismatch: "typeMismatch"
        case .valueNotFound: "valueNotFound"
        @unknown default: "unknown"
        }
    }
    
    // See `CustomStringConvertible.description`.
    public var description: String {
        "Decoding error: \(self.reason)"
    }

    // See `AbortError.reason`
    public var reason: String {
        switch self {
        case let .dataCorrupted(ctx):       "Data corrupted \(self.contextReason(ctx))"
        case let .keyNotFound(key, ctx):    "No such key '\(key.stringValue)' \(self.contextReason(ctx))"
        case let .typeMismatch(type, ctx):  "Value was not of type '\(type)' \(self.contextReason(ctx))"
        case let .valueNotFound(type, ctx): "No value found (expected type '\(type)') \(self.contextReason(ctx))"
        @unknown default:                   "Unknown error"
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
            ""
        } else if self.debugDescription.last == "." {
            ". \(self.debugDescription.dropLast())"
        } else {
            ". \(self.debugDescription)"
        }
    }
    
    private var underlyingErrorDescription: String {
        self.underlyingError.map { ". Underlying error: \(String(describing: $0))" } ?? ""
    }
}
