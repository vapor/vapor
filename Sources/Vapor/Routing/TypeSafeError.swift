import TypeSafeRouting
import HTTP

extension TypeSafeRoutingError: AbortError {
    public var status: Status {
        return .badRequest
    }
    
    public var reason: String {
        switch self {
        case .invalidParameterType(let type):
            return "Invalid parameter type, expected: \(type)"
        case .missingParameter:
            return "Missing routing parameter"
        }
    }
}
