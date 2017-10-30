import Async

/// A Fluent database query builder.
public final class QueryBuilder<M: Model> {
    /// The query we are building
    public var query: DatabaseQuery

    /// The connection this query will be excuted on.
    public let executor: QueryExecutor

    /// Create a new query.
    public init(
        _ type: M.Type = M.self,
        on executor: QueryExecutor
    ) {
        query = DatabaseQuery(entity: M.entity)
        self.executor = executor
    }
}

// MARK: Save

extension QueryBuilder {
    /// Saves the supplied model.
    /// If `shouldCreate` is true, the model will be saved
    /// as a new item even if it already has an identifier.
    public func save(
        _ model: inout M,
        shouldCreate: Bool = false
    ) -> Future<Void> {
        query.data = model

        if let id = model.id, !shouldCreate {
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
