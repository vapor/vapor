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
    /// Applies a filter from one of the filter operators (==, !=, etc)
    @discardableResult
    public func filter(
        _ value: QueryFilterMethod
    ) -> Self {
        let filter = QueryFilter(entity: Model.entity, method: value)
        return addFilter(filter)
    }

    /// Applies a filter from one of the filter operators (==, !=, etc)
    /// note: this method is generic, allowing you to omit type names
    /// when filtering using key paths.
    @discardableResult
    public func filter(
        _ value: ModelFilterMethod<Model>
    ) -> Self {
        let filter = QueryFilter(entity: Model.entity, method: value.method)
        return addFilter(filter)
    }
}

/// Typed wrapper around query filter methods.
public struct ModelFilterMethod<M> where M: Model {
    /// The wrapped query filter method.
    public let method: QueryFilterMethod

    /// Creates a new model filter method.
    public init(method: QueryFilterMethod) {
        self.method = method
    }
}
