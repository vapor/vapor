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
>(lhs: Field, rhs: Value) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .equality(.equals), .value(rhs))
}

public func == <
    Root: Model,
    Value: Encodable & Equatable,
    Key: KeyPath<Root, Value>
>(lhs: Key, rhs: Value) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .equality(.equals), .value(rhs))
}

public func == <
    Root: Model,
    Value: Encodable & Equatable,
    Key: KeyPath<Root, Value?>
>(lhs: Key, rhs: Value) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .equality(.equals), .value(rhs))
}

extension KeyPath where Root: Model {
    func makeQueryField() -> QueryField {
        return Root.keyFieldMap[self]! // FIXME: throw an error i guess :(
    }
}

public func == <
    Field: QueryFieldRepresentable
>(lhs: Field, rhs: QueryField) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .equality(.equals), .field(rhs))
}

/// .notEquals
public func != <
    Field: QueryFieldRepresentable,
    Value: Encodable & Equatable
>(lhs: Field, rhs: Value) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .equality(.notEquals), .value(rhs))
}

public func != <
    Field: QueryFieldRepresentable
>(lhs: Field, rhs: QueryField) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .equality(.notEquals), .field(rhs))
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
        return filter(.compare(field.makeQueryField(), .sequence(comparison), .value(value)))
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
>(lhs: Field, rhs: Value) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .order(.greaterThan), .value(rhs))
}

/// .lessThan
public func < <
    Field: QueryFieldRepresentable,
    Value: Encodable & Comparable
>(lhs: Field, rhs: Value) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .order(.lessThan), .value(rhs))
}

/// .greaterThanOrEquals
public func >= <
    Field: QueryFieldRepresentable,
    Value: Encodable & Comparable
>(lhs: Field, rhs: Value) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .order(.greaterThanOrEquals), .value(rhs))
}

/// .lessThanOrEquals
public func <= <
    Field: QueryFieldRepresentable,
    Value: Encodable & Comparable
>(lhs: Field, rhs: Value) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .order(.lessThanOrEquals), .value(rhs))
}

/// Field

/// .greaterThan
public func > <
    Field: QueryFieldRepresentable
>(lhs: Field, rhs: QueryField) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .order(.greaterThan), .field(rhs))
}

/// .lessThan
public func < <
    Field: QueryFieldRepresentable
>(lhs: Field, rhs: QueryField) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .order(.lessThan), .field(rhs))
}

/// .greaterThanOrEquals
public func >= <
    Field: QueryFieldRepresentable
>(lhs: Field, rhs: QueryField) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .order(.greaterThanOrEquals), .field(rhs))
}

/// .lessThanOrEquals
public func <= <
    Field: QueryFieldRepresentable
>(lhs: Field, rhs: QueryField) -> QueryFilterMethod {
    return .compare(lhs.makeQueryField(), .order(.lessThanOrEquals), .field(rhs))
}
