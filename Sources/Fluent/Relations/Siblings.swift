import Async

public struct Siblings<From: Model, To: Model, Through: Pivot> {
    /// The base model which all fetched models
    /// should be related to.
    public let from: From

    /// The From model's foreign id key.
    /// This is usually From.foreignIDKey.
    /// note: This is used to filter the pivot.
    public let fromForeignIDKey: String

    /// The To model's foreign id key.
    /// This is usually To.foreignIDKey.
    /// note: This is used to join the pivot.
    public let toForeignIDKey: String

    /// Create a new Siblings relation.
    public init(
        from: From,
        to: To.Type = To.self,
        through: Through.Type = Through.self,
        fromForeignIDKey: String = From.foreignIDKey,
        toForeignIDKey: String = To.foreignIDKey
    ) {
        self.from = from
        self.fromForeignIDKey = fromForeignIDKey
        self.toForeignIDKey = toForeignIDKey
    }

    /// Create a query for the parent.
    public func query(on executor: QueryExecutor) -> QueryBuilder<To> {
        return executor.query(To.self)
            .join(Through.self, joinedKey: toForeignIDKey)
            .filter(Through.self, fromForeignIDKey == from.id)
    }
}

// MARK: ModifiablePivot

extension Siblings where Through: ModifiablePivot {
    /// Returns true if the supplied model is attached
    /// to this relationship.
    public func isAttached(_ model: To, on executor: QueryExecutor) -> Future<Bool> {
        return executor.query(Through.self)
            .filter(From.foreignIDKey == from.id)
            .filter(To.foreignIDKey == model.id)
            .first()
            .map { $0 != nil }
    }

    /// Detaches the supplied model from this relationship
    /// if it was attached.
    public func detach(_ model: To, on executor: QueryExecutor) -> Future<Void> {
        return executor.query(Through.self)
            .filter(From.foreignIDKey == from.id)
            .filter(To.foreignIDKey == model.id)
            .delete()
    }
}

/// Left-side
extension Siblings where Through: ModifiablePivot, Through.Left == From, Through.Right == To {
    /// Attaches the model to this relationship.
    public func attach(_ model: To, on executor: QueryExecutor) -> Future<Void> {
        do {
            let pivot = try Through(from, model)
            return pivot.save(on: executor)
        } catch {
            return Future(error: error)
        }
    }
}

/// Right-side
extension Siblings where Through: ModifiablePivot, Through.Left == To, Through.Right == From {
    /// Attaches the model to this relationship.
    public func attach(_ model: To, on executor: QueryExecutor) -> Future<Void> {
        do {
            let pivot = try Through(model, from)
            return pivot.save(on: executor)
        } catch {
            return Future(error: error)
        }
    }
}


// MARK: Model

extension Model {
    /// Create a siblings relation for this model.
    public func siblings<To: Model, Through: Pivot>(
        to: To.Type = To.self,
        through: Through.Type = Through.self,
        fromForeignIDKey: String = Self.foreignIDKey,
        toForeignIDKey: String = To.foreignIDKey
    ) -> Siblings<Self, To, Through> {
        return Siblings(
            from: self,
            fromForeignIDKey: fromForeignIDKey,
            toForeignIDKey: toForeignIDKey
        )
    }
}
