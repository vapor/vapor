import Async

/// A siblings relation is a many-to-many relation between
/// two models.
///
/// Each model should have an opposite Siblings relation.
///
///     typealias PetToyPivot = BasicPivot<Pet, Toy> // or custom `Pivot`
///
///     class Pet: Model {
///         var toys: Siblings<Pet, Toy, PetToyPivot> {
///             return siblings()
///         }
///     }
///
///     class Toy: Model {
///         var pets: Siblings<Toy, Pet, PetToyPivot> {
///             return siblings()
///         }
///     }
///
/// The third generic parameter to this relation is a Pivot.
/// Althrough not enforced by compiler (due to the handedness), the Through pivot _must_
/// have Left & Right model types equal to the siblings From & To models.
/// (This cannot be enforced by the compiler due to the handedness)
///
/// In other words a pivot for Foo & Bar should not be used in a siblings
/// relation between Boo & Baz.
///
/// It is recommended that you use your own types conforming to `Pivot`
/// for Siblings pivots as you cannot add additional fields to a `BasicPivot`.
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
    public func query(on executor: QueryExecutor) throws -> QueryBuilder<To> {
        return try executor.query(To.self)
            .join(Through.self, joinedKey: toForeignIDKey)
            .filter(Through.field(fromForeignIDKey) == from.requireID())
    }
}

// MARK: ModifiablePivot

extension Siblings where Through: ModifiablePivot {
    /// Returns true if the supplied model is attached
    /// to this relationship.
    public func isAttached(_ model: To, on executor: QueryExecutor) throws -> Future<Bool> {
        return try executor.query(Through.self)
            .filter(From.field(fromForeignIDKey) == from.requireID())
            .filter(To.field(toForeignIDKey) == model.requireID())
            .first()
            .map { $0 != nil }
    }

    /// Detaches the supplied model from this relationship
    /// if it was attached.
    public func detach(_ model: To, on executor: QueryExecutor) throws -> Future<Void> {
        return try executor.query(Through.self)
            .filter(From.field(fromForeignIDKey) == from.requireID())
            .filter(To.field(toForeignIDKey) == model.requireID())
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
