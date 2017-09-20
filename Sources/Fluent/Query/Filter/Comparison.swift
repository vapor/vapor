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

public func == (lhs: String, rhs: NodeRepresentable) throws -> Filter.Method {
    let node = try rhs.makeNode(in: rowContext)
    return .compare(lhs, .equals, node)
}

public func > (lhs: String, rhs: NodeRepresentable) throws -> Filter.Method {
    let node = try rhs.makeNode(in: rowContext)
    return .compare(lhs, .greaterThan, node)
}

public func < (lhs: String, rhs: NodeRepresentable) throws -> Filter.Method {
    let node = try rhs.makeNode(in: rowContext)
    return .compare(lhs, .lessThan, node)
}

public func >= (lhs: String, rhs: NodeRepresentable) throws -> Filter.Method {
    let node = try rhs.makeNode(in: rowContext)
    return .compare(lhs, .greaterThanOrEquals, node)
}

public func <= (lhs: String, rhs: NodeRepresentable) throws -> Filter.Method {
    let node = try rhs.makeNode(in: rowContext)
    return .compare(lhs, .lessThanOrEquals, node)
}

public func != (lhs: String, rhs: NodeRepresentable) throws -> Filter.Method {
    let node = try rhs.makeNode(in: rowContext)
    return .compare(lhs, .notEquals, node)
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
