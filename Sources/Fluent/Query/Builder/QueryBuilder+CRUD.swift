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
        return then {
            self.query.data = model
            self.query.action = .create

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

            return try model.willCreate(on: self.connection)
                .then(self.run)
                .then { try model.didCreate(on: self.connection) }
        }
    }

    /// Updates the model. This requires that
    /// the model has its ID set.
    public func update(_ model: Model) -> Future<Void> {
        return then {
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


            return try model.willUpdate(on: self.connection)
                .then(self.run)
                .then { try model.didUpdate(on: self.connection) }
        }
    }

    /// Deletes the supplied model.
    /// Throws an error if the mdoel did not have an id.
    internal func delete(_ model: Model) -> Future<Void> {
        if let type = Model.self as? (_SoftDeletable & KeyFieldMappable).Type
        {
            /// model is soft deletable
            let path = type._deletedAtKey
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
        return then {
            return try model.willDelete(on: self.connection).then { _ -> Future<Void> in 
                guard let id = model.fluentID else {
                    throw "model does not have an id"
                }

                try self.filter(Model.idKey == id)
                self.query.action = .delete
                return self.run().then { try model.didDelete(on: self.connection) }
            }
        }
    }
}
