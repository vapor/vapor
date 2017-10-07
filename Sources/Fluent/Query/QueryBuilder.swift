import Async

/// A Fluent database query.
public final class QueryBuilder<M: Model> {
    /// The query we are building
    public var query: DatabaseQuery

    /// The connection this query will be excuted on.
    public let connection: Future<DatabaseConnection>

    /// Create a new query.
    public init(
        _ type: M.Type = M.self,
        on connection: Future<DatabaseConnection>
    ) {
        query = DatabaseQuery(entity: M.entity)
        self.connection = connection
    }
}

// MARK: CRUD

extension QueryBuilder {
    public func save() -> Future<Void> {
        query.action = .data(.update) // TODO: check if exists
        return all().map { _ in Void() }
    }
}

// MARK: Convenience
extension QueryBuilder {
    /// Convenience init with non-future connection.
    public convenience init(
        _ type: M.Type = M.self,
        on conn: DatabaseConnection
    ) {
        self.init(M.self, on: Future(conn))
    }
}
