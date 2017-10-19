import Async

/// A Fluent database query.
public final class QueryBuilder<M: Model> {
    /// The query we are building
    public var query: DatabaseQuery

    /// The connection this query will be excuted on.
    public let executor: Future<QueryExecutor>

    /// Create a new query.
    public init(
        _ type: M.Type = M.self,
        on executor: Future<QueryExecutor>
    ) {
        query = DatabaseQuery(entity: M.entity)
        self.executor = executor
    }
}

// MARK: CRUD

extension QueryBuilder {
    public func save() -> Future<Void> {
        query.action = .update // TODO: check if exists
        return all().map { _ in Void() }
    }
}

// MARK: Convenience
extension QueryBuilder {
    /// Convenience init with non-future connection.
    public convenience init(
        _ type: M.Type = M.self,
        on executor: QueryExecutor
    ) {
        self.init(M.self, on: Future(executor))
    }

    /// Create a new query.
    public convenience init(
        _ type: M.Type = M.self,
        on conn: Future<DatabaseConnection>
    ) {
        let promise = Promise(QueryExecutor.self)
        conn.then(promise.complete).catch(promise.fail)
        self.init(M.self, on: promise.future)
    }
}
