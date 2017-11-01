/// Sorts results based on a field
/// and direction.
public struct Sort {
    /// The entity to sort.
    public let entity: String

    /// The name of the field to sort.
    public let field: String

    /// The direction to sort by.
    public let direction: SortDirection

    /// Create a new sort
    public init<M: Model>(
        _ model: M.Type = M.self,
        field: String,
        direction: SortDirection
    ) {
        self.entity = M.entity
        self.field = field
        self.direction = direction
    }
}

/// The types of directions
/// fields can be sorted.
public enum SortDirection {
    case ascending
    case descending
}

// MARK: Builder

extension QueryBuilder {
    /// Add a Sort to the Query.
    public func sort<M: Model>(_ model: M.Type = M.self, _ field: String, _ direction: SortDirection) -> Self {
        let sort = Sort(M.self, field: field, direction: direction)
        return self.sort(sort)
    }

    /// Add a Sort to the Query.
    public func sort(_ field: String, _ direction: SortDirection) -> Self {
        return sort(M.self, field, direction)
    }

    /// Add a Sort to the Query.
    public func sort(_ sort: Sort) -> Self {
        query.sorts.append(sort)
        return self
    }
}
