import Vapor

enum MinimumError: String {
    case alpha, beta, charlie
}

extension MinimumError: Debuggable {
    /// The reason for the error.
    /// Typical implementations will switch over `self`
    /// and return a friendly `String` describing the error.
    /// - note: It is most convenient that `self` be a `Swift.Error`.
    ///
    /// Here is one way to do this:
    ///
    ///     switch self {
    ///     case someError:
    ///        return "A `String` describing what went wrong including the actual error: `Error.someError`."
    ///     // other cases
    ///     }
    var reason: String {
        switch self {
            case .alpha:
                return "Not enabled"
            case .beta:
                return "Enabled, but I'm not configured"
            case .charlie:
                return "Broken beyond repair"
        }
    }

    var identifier: String {
        return rawValue
    }

    /// A `String` array describing the possible causes of the error.
    /// - note: Defaults to an empty array.
    /// Provide a custom implementation to give more context.
    var possibleCauses: [String] {
        return []
    }

    var suggestedFixes: [String] {
        return []
    }
}
