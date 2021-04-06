import MultipartKit

extension MultipartError: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .nesting:
            return .notImplemented
        default:
            return .badRequest
        }
    }
}
