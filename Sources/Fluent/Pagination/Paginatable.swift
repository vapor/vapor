// Conforming to this protocol allows the entity
// to be paginated using `query.paginate()`
public protocol Paginatable: Model {
    static var defaultPageSize: Int { get }
    static var maxPageSize: Int? { get }
    static var defaultPageSorts: [Sort] { get }
}

// MARK: Optional

public var defaultPageSize: Int = 10

extension Paginatable {
    public static var defaultPageSize: Int {
        return Fluent.defaultPageSize
    }
    
    public static var maxPageSize: Int? {
        return nil
    }
}

extension Paginatable where Self: Timestampable {
    public static var defaultPageSorts: [Sort] {
        return [
            Sort(self, Self.createdAtKey, .descending)
        ]
    }
}
