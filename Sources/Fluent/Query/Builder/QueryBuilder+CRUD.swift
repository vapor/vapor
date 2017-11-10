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

            return try model.willCreate()
                .then(self.run)
                .then(model.didCreate)
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


            return try model.willUpdate()
                .then(self.run)
                .then(model.didUpdate)
        }
    }

    /// Deletes the supplied model.
    /// Throws an error if the mdoel did not have an id.
    public func delete(_ model: Model) -> Future<Void> {
        return then {
            return try model.willDelete().then {
                guard let id = model.fluentID else {
                    throw "model does not have an id"
                }

                try self.filter(Model.idKey == id)
                self.query.action = .delete
                return self.run().then(model.didDelete)
            }
        }
    }
}
