import Async
import Fluent
import Foundation

/// A pivot between pet and toy.
final class PetToy<D: Database>: ModifiablePivot {
    /// See Model.database
    typealias Database = D

    /// See Model.ID
    typealias ID = UUID

    /// See Pivot.Left
    typealias Left = Pet<Database>

    /// See Pivot.Right
    typealias Right = Toy<Database>

    /// See Model.idKey
    static var idKey: IDKey { return \.id }

    /// See Pivot.leftIDKey
    static var leftIDKey: LeftIDKey { return \.petID }

    /// See Pivot.rightIDKey
    static var rightIDKey: RightIDKey { return \.toyID }

    /// See Model.keyFieldMap
    static var keyFieldMap: KeyFieldMap {
        return [
            key(\.id): field("id"),
            key(\.petID): field("petID"),
            key(\.toyID): field("toyID")
        ]
    }

    /// PetToy's identifier
    var id: UUID?

    /// The pet's id
    var petID: UUID

    /// The toy's id
    var toyID: UUID

    /// See ModifiablePivot.init
    init(_ pet: Pet<Database>, _ toy: Toy<Database>) throws {
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
            try builder.id()
            try builder.field(for: \.petID)
            try builder.field(for: \.toyID)
        }
    }

    /// See Migration.revert
    static func revert(on connection: Database.Connection) -> Future<Void> {
        return connection.delete(PetToy<Database>.self)
    }
}

