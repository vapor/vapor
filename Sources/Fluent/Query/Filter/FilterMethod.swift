/// Types of fluent filters.
public enum FilterMethod {
    case compare(String, Comparison, Encodable)
    case subset(String, SubsetScope, [Encodable])
    case group(Relation, [Filter])
}

public func == (lhs: String, rhs: Encodable) throws -> FilterMethod {
    return .compare(lhs, .equals, rhs)
}

public func > (lhs: String, rhs: Encodable) throws -> FilterMethod {
    return .compare(lhs, .greaterThan, rhs)
}

public func < (lhs: String, rhs: Encodable) throws -> FilterMethod {
    return .compare(lhs, .lessThan, rhs)
}

public func >= (lhs: String, rhs: Encodable) throws -> FilterMethod {
    return .compare(lhs, .greaterThanOrEquals, rhs)
}

public func <= (lhs: String, rhs: Encodable) throws -> FilterMethod {
    return .compare(lhs, .lessThanOrEquals, rhs)
}

public func != (lhs: String, rhs: Encodable) throws -> FilterMethod {
    return .compare(lhs, .notEquals, rhs)
}

extension QueryBuilder {
    /// Entity operator filter queries
    @discardableResult
    public func filter<T: Model>(
        _ entity: T.Type,
        _ value: FilterMethod
    ) throws -> Self {
        let filter = Filter(entity: T.entity, method: value)
        return try self.filter(filter)
    }

    /// Self operator filter queries
    @discardableResult
    public func filter(
        _ value: FilterMethod
    ) throws -> Self {
        let filter = Filter(entity: M.entity, method: value)
        return try self.filter(filter)
    }
}
