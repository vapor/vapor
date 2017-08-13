import Core

/// Supported data types for storing
// and fetching from a `Session`.
public enum SessionData {
    case string(String)
    case array([SessionData])
    case dictionary([String: SessionData])
    case null
}


// Convenience accessors like `.string`.
extension SessionData: Polymorphic {
    public var string: String? {
        switch self {
        case .string(let str):
            return str
        default:
            return nil
        }
    }

    public var dictionary: [String : SessionData]? {
        switch self {
        case .dictionary(let dict):
            return dict
        default:
            return nil
        }
    }

    public var array: [SessionData]? {
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

// Instances of `SessionData` can be compared.
extension SessionData: Equatable {
    public static func ==(lhs: SessionData, rhs: SessionData) -> Bool {
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

// MARK: Expressible

extension SessionData: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: SessionData...) {
        self = .array(elements)
    }
}

extension SessionData: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, SessionData)...) {
        self = .dictionary(Dictionary(uniqueKeysWithValues: elements) )
    }
}

extension SessionData: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension SessionData: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}


