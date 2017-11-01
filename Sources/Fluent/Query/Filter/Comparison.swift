// MARK: Equality

/// Comparisons that require an equatable value.
public enum EqualityComparison {
    case equals
    case notEquals
}

/// .equals
public func == <
    Field: QueryFieldRepresentable,
    Value: Encodable & Equatable
>(lhs: Field, rhs: Value) -> FilterMethod {
    return .equality(lhs.makeQueryField(), .equals, .value(rhs))
}

public func == <
    Field: QueryFieldRepresentable
>(lhs: Field, rhs: QueryField) -> FilterMethod {
    return .equality(lhs.makeQueryField(), .equals, .field(rhs))
}

/// .notEquals
public func != <
    Field: QueryFieldRepresentable,
    Value: Encodable & Sequence
>(lhs: Field, rhs: Value) -> FilterMethod {
    return .equality(lhs.makeQueryField(), .notEquals, .value(rhs))
}

// MARK: Sequence

/// Comparisons that require a sequence value.
public enum SequenceComparison {
    case hasSuffix
    case hasPrefix
    case contains
}

extension QueryBuilder {
    /// Add a sequence comparison to the query builder.
    public func filter<
        Field: QueryFieldRepresentable,
        Value: Encodable & Sequence
    >(
        _ field: Field,
        _ comparison: SequenceComparison,
        _ value: Value
    ) -> Self {
        return filter(.sequence(field.makeQueryField(), comparison, .value(value)))
    }
}

// MARK: Ordered

/// Comparisons that require an ordered value.
public enum OrderedComparison {
    case greaterThan
    case lessThan
    case greaterThanOrEquals
    case lessThanOrEquals
}

/// .greaterThan
public func > <
    Field: QueryFieldRepresentable,
    Value: Encodable & Comparable
>(lhs: Field, rhs: Value) -> FilterMethod {
    return .order(lhs.makeQueryField(), .greaterThan, .value(rhs))
}

/// .lessThan
public func < <
    Field: QueryFieldRepresentable,
    Value: Encodable & Comparable
>(lhs: Field, rhs: Value) -> FilterMethod {
    return .order(lhs.makeQueryField(), .lessThan, .value(rhs))
}

/// .greaterThanOrEquals
public func >= <
    Field: QueryFieldRepresentable,
    Value: Encodable & Comparable
>(lhs: Field, rhs: Value) -> FilterMethod {
    return .order(lhs.makeQueryField(), .greaterThanOrEquals, .value(rhs))
}

/// .lessThanOrEquals
public func <= <
    Field: QueryFieldRepresentable,
    Value: Encodable & Comparable
>(lhs: Field, rhs: Value) -> FilterMethod {
    return .order(lhs.makeQueryField(), .lessThanOrEquals, .value(rhs))
}
