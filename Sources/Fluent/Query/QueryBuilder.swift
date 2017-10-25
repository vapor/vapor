import Async

/// A Fluent database query.
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
    public func save(
        _ model: inout M,
        new: Bool = false
    ) -> Future<Void> {
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

// MARK: Convenience - Fix w/ conditional conformance
extension Future: QueryExecutor {
    public func execute(transaction: DatabaseTransaction) -> Future<Void> {
        let promise = Promise(Void.self)

        self.then { result in
            if let executor = result as? QueryExecutor {
                executor.execute(transaction: transaction)
                    .chain(to: promise)
            } else {
                promise.fail("future not query executor type")
            }
        }.catch(promise.fail)

        return promise.future
    }

    public func execute<I: InputStream, D: Decodable>(
        query: DatabaseQuery,
        into stream: I
    ) -> Future<Void> where I.Input == D {
        let promise = Promise(Void.self)

        self.then { result in
            if let executor = result as? QueryExecutor {
                executor.execute(query: query, into: stream)
                    .chain(to: promise)
            } else {
                promise.fail("future not query executor type")
            }
        }.catch(promise.fail)

        return promise.future
    }
}
