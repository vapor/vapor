import Async
import Fluent
import Foundation
import SQLite
import FluentSQLite

final class PetToyPivot: ModifiablePivot {
    typealias Left = Pet
    typealias Right = Toy

    static let idKey = \PetToyPivot.id
    static let leftIDKey = \PetToyPivot.petID
    static var rightIDKey = \PetToyPivot.toyID

    static let keyFieldMap = [
        key(\.id): field("id"),
        key(\.petID): field("petID"),
        key(\.toyID): field("toyID")
    ]

    var id: UUID?
    var petID: UUID
    var toyID: UUID

    init(_ pet: Pet, _ toy: Toy) throws {
        petID = try pet.requireID()
        toyID = try toy.requireID()
    }
}

extension PetToyPivot: Migration {
    typealias Database = SQLiteDatabase

    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        return connection.create(self) { builder in
            builder.id()
            builder.id(for: Pet.self, key: \.petID)
            builder.id(for: Toy.self, key: \.toyID)
        }
    }

    static func revert(on connection: SQLiteConnection) -> Future<Void> {
        return connection.delete(self)
    }
}
