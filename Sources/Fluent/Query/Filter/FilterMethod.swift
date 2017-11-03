/// Types of fluent filters.
public enum QueryFilterMethod {
    case compare(QueryField, QueryComparison, QueryComparisonValue)
    case subset(QueryField, QuerySubsetScope, QuerySubsetValue)
    case group(QueryGroupRelation, [QueryFilter])
}

public enum QueryComparison {
    case equality(EqualityComparison) // Encodable & Equatable
    case order(OrderedComparison) // Encodable & Comparable
    case sequence(SequenceComparison) // Encodable & Sequence
}

public enum QueryComparisonValue {
    case value(Encodable)
    case field(QueryField)
}

/// Generic filter method acceptors.
extension QueryBuilder {
    /// Self operator filter queries
    @discardableResult
    public func filter(
        _ value: QueryFilterMethod
    ) -> Self {
        let filter = QueryFilter(entity: Model.entity, method: value)
        return addFilter(filter)
    }
}
