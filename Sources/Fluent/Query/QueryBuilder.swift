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
