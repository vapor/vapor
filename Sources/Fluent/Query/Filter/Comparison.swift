extension Filter {
    /// Describes the various operators for
    /// comparing values.
    public enum Comparison {
        case equals
        case greaterThan
        case lessThan
        case greaterThanOrEquals
        case lessThanOrEquals
        case notEquals
        case hasSuffix
        case hasPrefix
        case contains
        case custom(String)
    }
    
}

public func == (lhs: String, rhs: Encodable) throws -> Filter.Method {
    return .compare(lhs, .equals, rhs)
}

public func > (lhs: String, rhs: Encodable) throws -> Filter.Method {
    return .compare(lhs, .greaterThan, rhs)
}

public func < (lhs: String, rhs: Encodable) throws -> Filter.Method {
    return .compare(lhs, .lessThan, rhs)
}

public func >= (lhs: String, rhs: Encodable) throws -> Filter.Method {
    return .compare(lhs, .greaterThanOrEquals, rhs)
}

public func <= (lhs: String, rhs: Encodable) throws -> Filter.Method {
    return .compare(lhs, .lessThanOrEquals, rhs)
}

public func != (lhs: String, rhs: Encodable) throws -> Filter.Method {
    return .compare(lhs, .notEquals, rhs)
}

extension Filter.Comparison: Equatable {
    public static func ==(lhs: Filter.Comparison, rhs: Filter.Comparison) -> Bool {
        switch (lhs, rhs) {
        case (.equals, .equals),
             (.greaterThan, .greaterThan),
             (.lessThan, .lessThan),
             (.greaterThanOrEquals, .greaterThanOrEquals),
             (.lessThanOrEquals, .lessThanOrEquals),
             (.notEquals, .notEquals),
             (.hasSuffix, .hasSuffix),
             (.hasPrefix, .hasPrefix),
             (.contains, .contains):
            return true
        case (.custom(let a), .custom(let b)):
            return a == b
        default:
            return false
        }
    }
}
