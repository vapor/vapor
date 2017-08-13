import Core

/// Supported data types for storing
// and fetching from a `Cache`.
public enum CacheData {
    case string(String)
    case array([CacheData])
    case dictionary([String: CacheData])
    case null
}

// MARK: Polymorphic

extension CacheData: Polymorphic {
    public var string: String? {
        switch self {
        case .string(let string):
            return string
        default:
            return nil
        }
    }

    public var int: Int? {
        return string?.int
    }

    public var double: Double? {
        return string?.double
    }

    public var bool: Bool? {
        return string?.bool
    }

    public var dictionary: [String : CacheData]? {
        switch self {
        case .dictionary(let dict):
            return dict
        default:
            return nil
        }
    }

    public var array: [CacheData]? {
        switch self {
        case .array(let arr):
            return arr
        default:
            return nil
        }
    }

    public var isNull: Bool {
        switch self {
        case .null:
            return true
        case .string(let str):
            return str.isNull
        default:
            return false
        }
    }
}

// MARK: Equatable

// Instances of `CacheData` can be compared.
extension CacheData: Equatable {
    public static func ==(lhs: CacheData, rhs: CacheData) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a), .string(let b)):
            return a == b
        case (.dictionary(let a), .dictionary(let b)):
            return a == b
        case (.array(let a), .array(let b)):
            return a == b
        case (.null, .null):
            return true
        default:
            return false
        }
    }
}
