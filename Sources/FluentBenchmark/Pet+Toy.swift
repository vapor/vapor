import Async
import Fluent
import Foundation

/// A pivot between pet and toy.
final class PetToy: ModifiablePivot {
    /// See Pivot.Left
    typealias Left = Pet

    /// See Pivot.Right
    typealias Right = Toy

    /// See Model.idKey
    static let idKey = \PetToy.id

    /// See Pivot.leftIDKey
    static let leftIDKey = \PetToy.petID

    /// See Pivot.rightIDKey
    static var rightIDKey = \PetToy.toyID

    /// See Model.keyFieldMap
    static let keyFieldMap = [
        key(\.id): field("id"),
        key(\.petID): field("petID"),
        key(\.toyID): field("toyID")
    ]

    /// PetToy's identifier
    var id: UUID?

    /// The pet's id
    var petID: UUID

    /// The toy's id
    var toyID: UUID

    /// See ModifiablePivot.init
    init(_ pet: Pet, _ toy: Toy) throws {
        petID = try pet.requireID()
        toyID = try toy.requireID()
    }
}

internal struct PetToyMigration<D: Database>: Migration where D.Connection: SchemaSupporting {
    /// See Migration.database
    typealias Database = D

    /// See Migration.prepare
    static func prepare(on connection: Database.Connection) -> Future<Void> {
        return connection.create(PetToy.self) { builder in
            try builder.id()
            try builder.field(for: \.petID)
            try builder.field(for: \.toyID)
        }
    }

    /// See Migration.revert
    static func revert(on connection: Database.Connection) -> Future<Void> {
        return connection.delete(PetToy.self)
    }
}

