import Foundation

/// Supported validation data.
public enum ValidationData {
    case string(String)
    case int(Int)
    case uint(UInt)
    case bool(Bool)
    case data(Data)
    case double(Double)
    case array([ValidationData])
    case dictionary([String: ValidationData])
    case validatable(Validatable)
    case null
}

/// Capable of being represented by validation data.
/// Custom types you want to validate must conform to this protocol.
public protocol ValidationDataRepresentable {
    /// Converts to validation data
    func makeValidationData() -> ValidationData
}

extension Bool: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .bool(self)
    }
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

extension Int8: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .int(Int(self))
    }
}

extension Int16: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .int(Int(self))
    }
}

extension Int32: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .int(Int(self))
    }
}

extension Int64: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .int(Int(self))
    }
}

extension UInt: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .uint(self)
    }
}

extension UInt8: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .uint(UInt(self))
    }
}

extension UInt16: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .uint(UInt(self))
    }
}

extension UInt32: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .uint(UInt(self))
    }
}

extension UInt64: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .uint(UInt(self))
    }
}

extension Double: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .double(self)
    }
}

extension Data: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        return .data(self)
    }
}

extension Array: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        var items: [ValidationData] = []
        for el in self {
            // FIXME: conditional conformance
            items.append((el as! ValidationDataRepresentable).makeValidationData())
        }
        return .array(items)
    }
}

extension Dictionary: ValidationDataRepresentable {
    /// See ValidationDataRepresentable.makeValidationData
    public func makeValidationData() -> ValidationData {
        var items: [String: ValidationData] = [:]
        for (key, el) in self {
            // FIXME: conditional conformance
            items[(key as! String)] = (el as! ValidationDataRepresentable).makeValidationData()
        }
        return .dictionary(items)
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
