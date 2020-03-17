/// Errors that can be thrown while working with Multipart.
public enum MultipartError: Error, CustomStringConvertible {
    case invalidFormat
    case convertibleType(Any.Type)
    case convertiblePart(Any.Type, MultipartPart)
    case nesting
    case missingPart(String)
    case missingFilename
    
    public var description: String {
        switch self {
        case .invalidFormat:
            return "Multipart data is not formatted correctly"
        case .convertibleType(let type):
            return "\(type) is not convertible to multipart data"
        case .convertiblePart(let type, let part):
            return "Multipart part is not convertible to \(type): \(part)"
        case .nesting:
            return "Nested multipart data is not supported"
        case .missingPart(let name):
            return "No multipart part named '\(name)' was found"
        case .missingFilename:
            return "Multipart part did not have a filename"
        }
    }
}
