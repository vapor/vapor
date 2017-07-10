
/// Typical errors that may happen
/// during the parsing of Vapor json
/// configuration files.
public enum ConfigError: Error {
    case unsupported(value: String, key: [String], file: String)
    case missing(key: [String], file: String, desiredType: Any.Type)
    case missingFile(String)
    case unspecified(Error)
    case unsupportedType(Any.Type)
}

extension ConfigError: CustomStringConvertible {
    public var description: String {
        let reason: String
        
        switch self {
        case .unsupported(let value, let key, let file):
            let keyPath = key.joined(separator: ".")
            reason = "Unsupported value \(value) for key \(keyPath) in Config/\(file).json"
        case .missing(let key, let file, let desiredType):
            let keyPath = key.joined(separator: ".")
            reason = "Key \(keyPath) in Config/\(file).json of type \(desiredType) required."
        case .missingFile(let file):
            reason = "Config/\(file).json required."
        case .unsupportedType(let type):
            reason = "Type \(type) not supported"
        case .unspecified(let error):
            reason = "\(error)"
        }
        
        return "Configuration error: \(reason)"
    }
}
