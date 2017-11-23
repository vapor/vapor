import Async
import Foundation

extension QueryBuilder {
    /// Saves the supplied model.
    /// Calls `create` if the ID is `nil`, and `update` if it exists.
    /// If you need to create a model with a pre-existing ID,
    /// call `create` instead.
    public func save(_ model: Model) -> Future<Void> {
        if model.fluentID != nil {
            return update(model)
        } else {
            return create(model)
        }
    }

    /// Saves this model as a new item in the database.
    /// This method can auto-generate an ID depending on ID type.
    public func create(_ model: Model) -> Future<Void> {
        self.query.data = model
        self.query.action = .create
        let query = self.query
        return connection.then { conn -> Future<Void> in
            if model.fluentID == nil {
                // generate an id
                switch Model.ID.identifierType {
                case .autoincrementing: break
                case .generated(let factory):
                    model.fluentID = factory()
                case .supplied: throw "model id type is `supplied`, but no id was supplied"
                }
            }

            // set timestamps
            if var timestampable = model as? Timestampable {
                let now = Date()
                timestampable.updatedAt = now
                timestampable.createdAt = now
            }

            let promise = Promise(Void.self)

            let stream = BasicStream<Model>()
            stream.drain { model in
                try model.parseID(from: conn)
            }.catch { err in
                promise.fail(err)
            }.finally {
                do {
                    try model.didCreate(on: conn)
                        .chain(to: promise)
                } catch {
                    promise.fail(error)
                }
            }

            return try model.willCreate(on: conn).then { _ -> Future<Void> in
                conn.execute(query: query, into: stream)
                
                return promise.future.do {
                    if  model.fluentID == nil,
                        case .autoincrementing(let factory) = Model.ID.identifierType,
                        let id = conn.lastAutoincrementID
                    {
                        model.fluentID = factory(id)
                    }
                }
            }
        }
    }

    /// Updates the model. This requires that
    /// the model has its ID set.
    public func update(_ model: Model) -> Future<Void> {
        return connection.then { conn -> Future<Void> in
            /// FIXME: must not capture self here
            self.query.data = model

            guard let id = model.fluentID else {
                throw "id required for update"
            }

            // update record w/ matching id
            try self.filter(Model.idKey == id)
            self.query.action = .update

            // update timestamps if required
            if var timestampable = model as? Timestampable {
                timestampable.updatedAt = Date()
            }


            return try model.willUpdate(on: conn)
                .then { self.run() }
                .then { try model.didUpdate(on: conn) }
        }
    }

    /// Deletes the supplied model.
    /// Throws an error if the mdoel did not have an id.
    internal func delete(_ model: Model) -> Future<Void> {
        if let type = Model.self as? AnySoftDeletable.Type
        {
            /// model is soft deletable
            let path = type.anyDeletedAtKey
                as! ReferenceWritableKeyPath<Model, Date?>
            model[keyPath: path] = Date()
            return update(model)
        } else {
            return _delete(model)
        }
    }

    /// Deletes the supplied model.
    /// Throws an error if the mdoel did not have an id.
    /// note: does NOT respect soft deletable.
    internal func _delete(_ model: Model) -> Future<Void> {
        return connection.then { conn in
            /// FIXME: must not capture self here
            return try model.willDelete(on: conn).then { _ -> Future<Void> in
                guard let id = model.fluentID else {
                    throw "model does not have an id"
                }

                try self.filter(Model.idKey == id)
                self.query.action = .delete
                return self.run().then { try model.didDelete(on: conn) }
            }
        }
    }
}
