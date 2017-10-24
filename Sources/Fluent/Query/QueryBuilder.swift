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

// MARK: Save

extension QueryBuilder {
    public func save(_ model: inout M, new: Bool) -> Future<Void> {
        query.data = model

        if let id = model.id, !new {
            filter("id" == id)
            // update record w/ matching id
            query.action = .update
        } else if model.id == nil {
            switch M.I.identifierType {
            case .autoincrementing: break
            case .generated(let factory):
                model.id = factory()
            case .supplied: break
                // FIXME: error if not actually supplied?
            }
            // create w/ generated id
            query.action = .create
        } else {
            // just create, with existing id
            query.action = .create
        }

        return run()
    }
}
