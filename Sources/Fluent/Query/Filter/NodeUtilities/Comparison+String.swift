/// Filter.Comparison <-> String
extension Filter.Comparison {
    public var string: String {
        switch(self) {
        case .equals: return "equals"
        case .greaterThan: return "greaterThan"
        case .lessThan: return "lessThan"
        case .greaterThanOrEquals: return "greaterThanOrEquals"
        case .lessThanOrEquals: return "lessThanOrEquals"
        case .notEquals: return "notEquals"
        case .hasSuffix: return "hasSuffix"
        case .hasPrefix: return "hasPrefix"
        case .contains: return "contains"
        case .custom(let s): return "custom(\(s))"
        }
    }

    /// Returns Filter.Comparison.custom("X") from a string "custom(X)"
    static func customFromString(_ string: String) throws -> Filter.Comparison {
        guard string.hasPrefix("custom(") && string.hasSuffix(")") else {
            throw FilterSerializationError.undefinedComparison(string)
        }
        let start = string.index(string.startIndex, offsetBy: 7)
        let end = string.index(string.endIndex, offsetBy: -1)
        return .custom(String(string[start..<end]))
    }

    public init(_ string: String) throws {
        switch(string) {
        case "equals": self = .equals
        case "greaterThan": self = .greaterThan
        case "lessThan": self = .lessThan
        case "greaterThanOrEquals": self = .greaterThanOrEquals
        case "lessThanOrEquals": self = .lessThanOrEquals
        case "notEquals": self = .notEquals
        case "hasSuffix": self = .hasSuffix
        case "hasPrefix": self = .hasPrefix
        case "contains": self = .contains
        default: self = try .customFromString(string)
        }
    }
}
