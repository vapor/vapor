/// Types of fluent filters.
public enum QueryFilterMethod {
    case compare(QueryField, QueryComparison, ComparisonValue)
    case subset(QueryField, SubsetScope, SubsetValue)
    case group(Relation, [QueryFilter])
}

public enum QueryComparison {
    case equality(EqualityComparison) // Encodable & Equatable
    case order(OrderedComparison) // Encodable & Comparable
    case sequence(SequenceComparison) // Encodable & Sequence
}

public enum ComparisonValue {
    case value(Encodable)
    case field(QueryField)
}

/// Generic filter method acceptors.
extension QueryBuilder {
    /// Entity operator filter queries
    @discardableResult
    public func filter<M: Model>(
        _ model: M.Type,
        _ value: QueryFilterMethod
    ) -> Self {
        let filter = QueryFilter(entity: M.entity, method: value)
        return addFilter(filter)
    }

    /// Self operator filter queries
    @discardableResult
    public func filter(
        _ value: QueryFilterMethod
    ) -> Self {
        let filter = QueryFilter(entity: M.entity, method: value)
        return addFilter(filter)
    }
}
