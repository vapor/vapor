/// Sorts results based on a field
/// and direction.
public struct Sort {
    /// The types of directions
    /// fields can be sorted.
    public enum Direction {
        case ascending, descending
    }

    /// The entity to sort.
    public let entity: Model.Type

    /// The name of the field to sort.
    public let field: String

    /// The direction to sort by.
    public let direction: Direction

    public init(_ entity: Model.Type, _ field: String, _ direction: Direction) {
        self.entity = entity
        self.field = field
        self.direction = direction
    }
}

extension QueryRepresentable where Self: ExecutorRepresentable {
    /// Add a Sort to the Query.
    /// See Sort for more information.
    @discardableResult
    public func sort(_ field: String, _ direction: Sort.Direction) throws -> Query<E> {
        let query = try makeQuery()
        let sort = Sort(E.self, field, direction)
        try query.sort(sort)
        return query
    }
    
    @discardableResult
    public func sort(_ sort: Sort) throws -> Query<E> {
        let query = try makeQuery()
        query.sorts.append(.some(sort))
        return query
    }
}
