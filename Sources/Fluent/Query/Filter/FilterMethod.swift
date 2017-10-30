/// Types of fluent filters.
public enum FilterMethod {
    case compare(String, Comparison, Encodable)
    case subset(String, SubsetScope, [Encodable])
    case group(Relation, [Filter])
}

/// .equals
public func == (lhs: String, rhs: Encodable) -> FilterMethod {
    return .compare(lhs, .equals, rhs)
}

/// .greaterThan
public func > (lhs: String, rhs: Encodable) -> FilterMethod {
    return .compare(lhs, .greaterThan, rhs)
}

/// .lessThan
public func < (lhs: String, rhs: Encodable) -> FilterMethod {
    return .compare(lhs, .lessThan, rhs)
}

/// .greaterThanOrEquals
public func >= (lhs: String, rhs: Encodable) -> FilterMethod {
    return .compare(lhs, .greaterThanOrEquals, rhs)
}

/// .lessThanOrEquals
public func <= (lhs: String, rhs: Encodable) -> FilterMethod {
    return .compare(lhs, .lessThanOrEquals, rhs)
}

/// .notEquals
public func != (lhs: String, rhs: Encodable) -> FilterMethod {
    return .compare(lhs, .notEquals, rhs)
}

extension QueryBuilder {
    /// Entity operator filter queries
    @discardableResult
    public func filter<T: Model>(
        _ entity: T.Type,
        _ value: FilterMethod
    ) -> Self {
        let filter = Filter(entity: T.entity, method: value)
        return addFilter(filter)
    }

    /// Self operator filter queries
    @discardableResult
    public func filter(
        _ value: FilterMethod
    ) -> Self {
        let filter = Filter(entity: M.entity, method: value)
        return addFilter(filter)
    }
}
