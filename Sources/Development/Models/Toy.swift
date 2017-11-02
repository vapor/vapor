import Async
import Fluent
import Foundation
import SQLite

final class Toy: Model {
    typealias ID = UUID

    static let keyFieldMap = [
        key(\.id): field("id"),
        key(\.name): field("name")
    ]

    static let idKey = \Toy.id

    var id: UUID?
    var name: String

    init(name: String) {
        self.name = name
    }

    var pets: Siblings<Toy, Pet, PetToyPivot> {
        return siblings(\.toyID, \.petID)
    }
}

extension Toy: Migration {
    typealias Database = SQLiteDatabase

    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        return connection.create(self) { builder in
            builder.id()
            builder.string("name")
        }
    }

    static func revert(on connection: SQLiteConnection) -> Future<Void> {
        return connection.delete(self)
    }
}
