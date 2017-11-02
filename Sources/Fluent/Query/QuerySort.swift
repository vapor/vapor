/// Sorts results based on a field
/// and direction.
public struct QuerySort {
    /// The field to sort.
    public let field: QueryField

    /// The direction to sort by.
    public let direction: QuerySortDirection

    /// Create a new sort
    public init(
        field: QueryField,
        direction: QuerySortDirection
    ) {
        self.field = field
        self.direction = direction
    }
}

/// The types of directions
/// fields can be sorted.
public enum QuerySortDirection {
    case ascending
    case descending
}

// MARK: Builder

extension QueryBuilder {
    /// Add a Sort to the Query.
    public func sort<F: QueryFieldRepresentable>(_ field: F, _ direction: QuerySortDirection) -> Self {
        let sort = QuerySort(field: field.makeQueryField(), direction: direction)
        return self.sort(sort)
    }
    
    /// Add a Sort to the Query.
    public func sort(_ sort: QuerySort) -> Self {
        query.sorts.append(sort)
        return self
    }
}
