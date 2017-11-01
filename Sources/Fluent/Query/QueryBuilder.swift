import Async
import Foundation

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
        _ model: M,
        shouldCreate: Bool = false
    ) -> Future<Void> {
        query.data = model

        if let id = model.id, !shouldCreate {
            filter("id" == id)
            // update record w/ matching id
            query.action = .update
        } else if model.id == nil {
            switch M.Identifier.identifierType {
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

        // update timestamps if required
        if var timestampable = model as? Timestampable {
            timestampable.updatedAt = Date()
            switch query.action {
            case .create: timestampable.createdAt = Date()
            default: break
            }
        }

        let promise = Promise(Void.self)

        do {
            switch query.action {
            case .create: try model.willCreate()
            case .update: try model.willUpdate()
            default: break
            }

            run().then {
                switch self.query.action {
                case .create: model.didCreate()
                case .update: model.didUpdate()
                default: break
                }
                promise.complete()
            }.catch(promise.fail)
        } catch {
            promise.fail(error)
        }

        return promise.future
    }

    /// Deletes the supplied model.
    /// Throws an error if the mdoel did not have an id.
    public func delete(_ model: M) -> Future<Void> {
        let promise = Promise(Void.self)

        do {
            try model.willDelete()

            if let id = model.id {
                filter("id" == id)
                query.action = .delete
                run().then {
                    model.didDelete()
                    promise.complete()
                }.catch(promise.fail)
            } else {
                promise.fail("model does not have an id")
            }
        } catch {
            promise.fail(error)
        }


        return promise.future
    }
}
