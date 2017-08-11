public struct URLEncodedError: Error {
    fileprivate let kind: Kind
    public let reason: String

    fileprivate init(kind: Kind, reason: String) {
        self.kind = kind
        self.reason = reason
    }

    public static func unsupportedTopLevel() -> URLEncodedError {
        return .init(
            kind: .unsupportedTopLevel,
            reason: "Only dictionary case is supported as top level URLEncodedForm."
        )
    }

    public static func unsupportedNesting(reason: String) -> URLEncodedError {
        return .init(
            kind: .unsupportedNesting,
            reason: "Unsupported nesting: \(reason)"
        )
    }

    public static func unableToEncode(string: String) -> URLEncodedError {
        return .init(
            kind: .unableToEncode,
            reason: "Unable to encode: \(string)"
        )
    }

    public static func unexpected(reason: String) -> URLEncodedError {
        return .init(
            kind: .unexpected,
            reason: reason
            
        )
    }
}

fileprivate enum Kind: String {
    case unsupportedNesting
    case unableToEncode
    case unsupportedTopLevel
    case unexpected
}
