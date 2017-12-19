import Async
import Fluent
import Foundation

/// A pivot between pet and toy.
public final class PetToy<D: Database>: ModifiablePivot {
    /// See Model.database
    public typealias Database = D

    /// See Model.ID
    public typealias ID = UUID

    /// See Pivot.Left
    public typealias Left = Pet<Database>

    /// See Pivot.Right
    public typealias Right = Toy<Database>

    /// See Model.idKey
    public static var idKey: IDKey { return \.id }

    /// See Pivot.leftIDKey
    public static var leftIDKey: LeftIDKey { return \.petID }

    /// See Pivot.rightIDKey
    public static var rightIDKey: RightIDKey { return \.toyID }

    /// See Model.database
    public static var database: DatabaseIdentifier<D> {
        return .init("test")
    }

    /// PetToy's identifier
    var id: UUID?

    /// The pet's id
    var petID: UUID

    /// The toy's id
    var toyID: UUID

    /// See ModifiablePivot.init
    public init(_ pet: Pet<Database>, _ toy: Toy<Database>) throws {
        petID = try pet.requireID()
        toyID = try toy.requireID()
    }
}

internal struct PetToyMigration<D: Database>: Migration where D.Connection: SchemaSupporting {
    /// See Migration.database
    typealias Database = D

    /// See Migration.prepare
    static func prepare(on connection: Database.Connection) -> Future<Void> {
        return connection.create(PetToy<Database>.self) { builder in
            try builder.field(for: \PetToy<Database>.id)
            try builder.field(for: \PetToy<Database>.petID)
            try builder.field(for: \PetToy<Database>.toyID)
        }
    }

    /// See Migration.revert
    static func revert(on connection: Database.Connection) -> Future<Void> {
        return connection.delete(PetToy<Database>.self)
    }
}
