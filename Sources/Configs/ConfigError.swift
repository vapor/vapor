
/// Typical errors that may happen
/// during the parsing of Vapor json
/// configuration files.
public enum ConfigError: Error {
    case unavailable(
        value: String,
        key: [String],
        file: String,
        available: [String],
        type: Any.Type
    )
    case unsupported(value: String, key: [String], file: String)
    case missing(key: [String], file: String, desiredType: Any.Type)
    case missingFile(String)
    case unspecified(Error)
    case maxResolve
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
        case .unavailable(let value, let key, let file, let available, let type):
            let list = available.joined(separator: ", ")
            let keyPath = key.joined(separator: ".")
            reason = "A \(type) named '\(value)' (chosen at '\(keyPath)' in Config/\(file).json) was not found (available: \(list))."
        case .unsupportedType(let type):
            reason = "Type \(type) not supported"
        case .maxResolve:
            reason = "Too many config resolution calls have been made. Check your dependencies for an infinite loop."
        case .unspecified(let error):
            reason = "\(error)"
        }
        
        return "Configuration error: \(reason)"
    }
}
