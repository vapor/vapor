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
public struct Siblings<Base: Model, Related: Model, Through: Pivot> {
    /// The base model which all fetched models
    /// should be related to.
    public let base: Base

    /// The base model's foreign id field
    /// that appears on the pivot.
    /// ex: Through.baseID
    public let basePivotField: QueryField

    /// The related model's foreign id field
    /// that appears on the pivot.
    /// ex: Through.relatedID
    public let relatedPivotField: QueryField

    /// Create a new Siblings relation.
    public init(
        base: Base,
        related: Related.Type = Related.self,
        through: Through.Type = Through.self,
        basePivotField: QueryField = Through.field(Base.foreignIDKey),
        relatedPivotField: QueryField = Through.field(Related.foreignIDKey)
    ) {
        self.base = base
        self.basePivotField = basePivotField
        self.relatedPivotField = relatedPivotField
    }

    /// Create a query for the parent.
    public func query(on executor: QueryExecutor) throws -> QueryBuilder<Related> {
        return try executor.query(Related.self)
            .join(field: relatedPivotField)
            .filter(basePivotField == base.requireID())
    }
}

// MARK: ModifiablePivot

extension Siblings where Through: ModifiablePivot {
    /// Returns true if the supplied model is attached
    /// to this relationship.
    public func isAttached(_ model: Related, on executor: QueryExecutor) throws -> Future<Bool> {
        return try executor.query(Through.self)
            .filter(basePivotField == base.requireID())
            .filter(relatedPivotField == model.requireID())
            .first()
            .map { $0 != nil }
    }

    /// Detaches the supplied model from this relationship
    /// if it was attached.
    public func detach(_ model: Related, on executor: QueryExecutor) throws -> Future<Void> {
        return try executor.query(Through.self)
            .filter(basePivotField == base.requireID())
            .filter(relatedPivotField == model.requireID())
            .delete()
    }
}

/// Left-side
extension Siblings where Through: ModifiablePivot, Through.Left == Base, Through.Right == Related {
    /// Attaches the model to this relationship.
    public func attach(_ model: Related, on executor: QueryExecutor) -> Future<Void> {
        do {
            let pivot = try Through(base, model)
            return pivot.save(on: executor)
        } catch {
            return Future(error: error)
        }
    }
}

/// Right-side
extension Siblings where Through: ModifiablePivot, Through.Left == Related, Through.Right == Base {
    /// Attaches the model to this relationship.
    public func attach(_ model: Related, on executor: QueryExecutor) -> Future<Void> {
        do {
            let pivot = try Through(model, base)
            return pivot.save(on: executor)
        } catch {
            return Future(error: error)
        }
    }
}


// MARK: Model

extension Model {
    /// Create a siblings relation for this model.
    ///
    /// Unless you are doing custom keys, you should not need to
    /// pass any parameters to this function.
    ///
    ///     class Toy: Model {
    ///         var pets: Siblings<Toy, Pet, PetToyPivot> {
    ///             return siblings()
    ///         }
    ///     }
    ///
    /// See Siblings class documentation for more information
    /// about the many parameters. They can be confusing at first!
    ///
    /// Note: From is assumed to be the model you are calling this method on.
    public func siblings<Related: Model, Through: Pivot>(
        related: Related.Type = Related.self,
        through: Through.Type = Through.self,
        basePivotField: QueryField = Through.field(Self.foreignIDKey),
        relatedPivotField: QueryField = Through.field(Related.foreignIDKey)
    ) -> Siblings<Self, Related, Through> {
        return Siblings(
            base: self,
            basePivotField: basePivotField,
            relatedPivotField: relatedPivotField
        )
    }
}
