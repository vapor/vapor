/// Supported validation data.
public enum ValidationData {
    case string(String)
    case int(Int)
    case validatable(Validatable)
    case null
}

/// Capable of being represented by validation data.
/// Custom types you want to validate must conform to this protocol.
public protocol ValidationDataRepresentable {
    /// Converts to validation data
    func makeValidationData() -> ValidationData
}

extension String: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .string(self)
    }
}

extension Int: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .int(self)
    }
}

extension Optional: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        switch self {
        case .none: return .null
        case .some(let s): return (s as? ValidationDataRepresentable)?.makeValidationData() ?? .null
        }
    }
}
