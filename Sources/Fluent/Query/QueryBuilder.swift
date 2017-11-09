import Async
import Foundation

/// A Fluent database query builder.
public final class QueryBuilder<
    Model: Fluent.Model,
    Connection: Fluent.Connection
> {
    /// The query we are building
    public var query: DatabaseQuery

    /// The connection this query will be excuted on.
    public let connection: Connection

    /// Create a new query.
    public init(
        _ model: Model.Type = Model.self,
        on connection: Connection
    ) {
        query = DatabaseQuery(entity: Model.entity)
        self.connection = connection
    }
}

// MARK: Save

extension QueryBuilder {
    /// Saves the supplied model.
    /// If `shouldCreate` is true, the model will be saved
    /// as a new item even if it already has an identifier.
    public func save(
        _ model: Model,
        shouldCreate: Bool = false
    ) -> Future<Void> {
        return then {
            self.query.data = model

            if let id = model.fluentID, !shouldCreate {
                try self.filter(Model.idKey == id)
                // update record w/ matching id
                self.query.action = .update
            } else if model.fluentID == nil {
                switch Model.ID.identifierType {
                case .autoincrementing: break
                case .generated(let factory):
                    model.fluentID = factory()
                case .supplied: break
                    // FIXME: error if not actually supplied?
                }
                // create w/ generated id
                self.query.action = .create
            } else {
                // just create, with existing id
                self.query.action = .create
            }

            // update timestamps if required
            if var timestampable = model as? Timestampable {
                timestampable.updatedAt = Date()
                switch self.query.action {
                case .create: timestampable.createdAt = Date()
                default: break
                }
            }

            let promise = Promise(Void.self)

            do {
                switch self.query.action {
                case .create: try model.willCreate()
                case .update: try model.willUpdate()
                default: break
                }

                self.run().do {
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
    }

    /// Deletes the supplied model.
    /// Throws an error if the mdoel did not have an id.
    public func delete(_ model: Model) -> Future<Void> {
        let promise = Promise(Void.self)

        do {
            try model.willDelete()

            if let id = model.fluentID {
                try filter(Model.idKey == id)
                query.action = .delete
                run().do {
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
