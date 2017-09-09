import Debugging

extension BCrypt {
    public enum Error: String, Swift.Error, Debuggable {
        case invalidHash
        case invalidSaltByteCount
        case invalidSaltVersion
        case invalidSaltCost
        case unsupportedSaltVersion
        
        public var reason: String {
            switch self {
            case .invalidHash:
                return "The hash being parsed does not match the recognized format"
            case .invalidSaltByteCount:
                return "BCrypt salt requires 16 exactly bytes"
            case .invalidSaltVersion:
                return "Invalid salt version format"
            case .invalidSaltCost:
                return "Invalid salt cost format"
            case .unsupportedSaltVersion:
                return "Unsupported salt version"
            }
        }
        
        public var identifier: String {
            return rawValue
        }
        
        public var possibleCauses: [String] {
            return [
                "BCrypt hash being parsed is not in the format `$2x$xx$ssssssssssssssssssssssddddddddddddddddddddddddddddddd`",
                "BCrypt hash is not base64 encoded properly"
            ]
        }
        
        public var suggestedFixes: [String] {
            return []
        }
    }
}
