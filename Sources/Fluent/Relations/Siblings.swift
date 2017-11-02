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

    /// The From model's local id field.
    /// ex: From.id
    public let fromIDField: QueryField

    /// The To model's local id field
    /// ex: To.id
    public let toIDField: QueryField

    /// The From model's foreign id field
    /// that appears on the pivot.
    /// ex: Through.fromID
    public let fromForeignIDField: QueryField

    /// The To model's foreign id field
    /// that appears on the pivot.
    /// ex: Through.toID
    public let toForeignIDField: QueryField

    /// Create a new Siblings relation.
    public init(
        from: From,
        to: To.Type = To.self,
        through: Through.Type = Through.self,
        fromIDField: QueryField = From.field(From.idKey),
        toIDField: QueryField = To.field(To.idKey),
        fromForeignIDField: QueryField = Through.field(From.foreignIDKey),
        toForeignIDField: QueryField = Through.field(To.foreignIDKey)
    ) {
        self.from = from
        self.fromIDField = fromIDField
        self.toIDField = toIDField
        self.fromForeignIDField = fromForeignIDField
        self.toForeignIDField = toForeignIDField
    }

    /// Create a query for the parent.
    public func query(on executor: QueryExecutor) throws -> QueryBuilder<To> {
        return try executor.query(To.self)
            .join(base: toIDField, joined: toForeignIDField)
            .filter(fromForeignIDField == from.requireID())
    }
}

// MARK: ModifiablePivot

extension Siblings where Through: ModifiablePivot {
    /// Returns true if the supplied model is attached
    /// to this relationship.
    public func isAttached(_ model: To, on executor: QueryExecutor) throws -> Future<Bool> {
        return try executor.query(Through.self)
            .filter(fromForeignIDField == from.requireID())
            .filter(toForeignIDField == model.requireID())
            .first()
            .map { $0 != nil }
    }

    /// Detaches the supplied model from this relationship
    /// if it was attached.
    public func detach(_ model: To, on executor: QueryExecutor) throws -> Future<Void> {
        return try executor.query(Through.self)
            .filter(fromForeignIDField == from.requireID())
            .filter(toForeignIDField == model.requireID())
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
        fromIDField: QueryField = Self.field(Self.idKey),
        toIDField: QueryField = To.field(To.idKey),
        fromForeignIDField: QueryField = Through.field(Self.foreignIDKey),
        toForeignIDField: QueryField = Through.field(To.foreignIDKey)
    ) -> Siblings<Self, To, Through> {
        return Siblings(
            from: self,
            fromIDField: fromIDField,
            toIDField: toIDField,
            fromForeignIDField: fromForeignIDField,
            toForeignIDField: toForeignIDField
        )
    }
}
