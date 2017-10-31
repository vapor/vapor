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
}

extension QueryBuilder {
    /// Filter entity with field, comparison, and value.
    @discardableResult
    public func filter<T: Model>(
        _ entity: T.Type,
        _ field: String,
        _ comparison: Comparison,
        _ value: Encodable?
    ) -> Self {
        let filter = Filter(entity: T.entity, method: .compare(field, comparison, value))
        return addFilter(filter)
    }

    /// Filter entity where field equals value
    @discardableResult
    public func filter<T: Model>(
        _ entity: T.Type,
        _ field: String,
        _ value: Encodable?
    ) -> Self {
        return filter(entity, field, .equals, value)
    }

    /// Filter self with field, comparison, and value.
    @discardableResult
    public func filter(
        _ field: String,
        _ comparison: Comparison,
        _ value: Encodable?
    ) -> Self {
        return filter(M.self, field, comparison, value)
    }

    /// Filter self where field equals value.
    @discardableResult
    public func filter(
        _ field: String,
        _ value: Encodable?
    )  -> Self {
        return filter(field, .equals, value)
    }
}
