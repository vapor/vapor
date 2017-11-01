/// Types of fluent filters.
public enum FilterMethod {
    case equality(QueryField, EqualityComparison, ComparisonValue) // Encodable & Equatable
    case order(QueryField, OrderedComparison, ComparisonValue) // Encodable & Comparable
    case sequence(QueryField, SequenceComparison, ComparisonValue) // Encodable & Sequence
    case subset(QueryField, SubsetScope, SubsetValue)
    case group(Relation, [Filter])
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
        _ value: FilterMethod
    ) -> Self {
        let filter = Filter(entity: M.entity, method: value)
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
