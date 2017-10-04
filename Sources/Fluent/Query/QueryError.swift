import Debugging

// FIXME: refactor to struct
public enum QueryError: Error {
    case notSupported(String)
    case invalidDriverResponse(String)
    case connectionClosed(Error)
    case entityRequired
    case unspecified(Error)
}

extension QueryError: Debuggable {
    public var identifier: String {
        switch self {
        case .notSupported(_):
            return "notSupported"
        case .invalidDriverResponse(_):
            return "invalidDriverResponse"
        case .connectionClosed(_):
            return "connectionClosed"
        case .entityRequired:
            return "entityRequired"
        case .unspecified(_):
            return "unspecified"
        }
    }

    public var reason: String {
        switch self {
        case .notSupported(let string):
            return "Not supported: \(string)"
        case .invalidDriverResponse(let string):
            return "Invalid driver response: \(string)"
        case .connectionClosed(let error):
            return "Connection is closed: \(error)"
        case .entityRequired:
            return "Entity required to save"
        case .unspecified(let error):
            return "\(error)"
        }
    }

    public var possibleCauses: [String] {
        return [
            "operation not supported by current database",
            "the database has become corrupted",
            "the database version doesn't have expected behavior"
        ]
    }

    public var suggestedFixes: [String] {
        return [
            "verify your database version is the expected one",
            "ensure your tables look as expected",
            "verify this operation is supported by your database"
        ]
    }
}
