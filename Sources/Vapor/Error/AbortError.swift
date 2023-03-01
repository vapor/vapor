import NIOHTTP1

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
    var status: HTTPResponseStatus { get }

    /// Optional `HTTPHeaders` to add to the error response.
    var headers: HTTPHeaders { get }
}

extension AbortError {
    /// See `AbortError`.
    public var headers: HTTPHeaders {
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
            return "Data corrupted at path '\(ctx.codingPath.dotPath)'\(ctx.debugDescriptionAndUnderlyingError)"
        case .keyNotFound(let key, let ctx):
            let path = ctx.codingPath + [key]
            return "Value required for key at path '\(path.dotPath)'\(ctx.debugDescriptionAndUnderlyingError)"
        case .typeMismatch(let type, let ctx):
            return "Value at path '\(ctx.codingPath.dotPath)' was not of type '\(type)'\(ctx.debugDescriptionAndUnderlyingError)"
        case .valueNotFound(let type, let ctx):
            return "Value of type '\(type)' was not found at path '\(ctx.codingPath.dotPath)'\(ctx.debugDescriptionAndUnderlyingError)"
        @unknown default: return "Unknown error."
        }
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
            return ". \(String(self.debugDescription.dropLast()))"
        } else {
            return ". \(self.debugDescription)"
        }
    }

    private var underlyingErrorDescription: String {
        if let underlyingError = self.underlyingError {
            return ". Underlying error: \(underlyingError)"
        } else {
            return ""
        }
    }
}
