import NIOHTTP1

/// Errors thrown while encoding/decoding `application/x-www-form-urlencoded` data.
enum URLEncodedFormError: Error {
    case malformedKey(key: Substring)
    case reachedNestingLimit
}

extension URLEncodedFormError: AbortError {
    var status: HTTPResponseStatus {
        .badRequest
    }

    var reason: String {
        switch self {
        case .malformedKey(let path):
            return "Malformed form-urlencoded key encountered: \(path)"
        case .reachedNestingLimit:
            return "The data supplied is too nested"
        }
    }
}
