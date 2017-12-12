import Async
import JunkDrawer
import Fluent
import Foundation
import SQLite

final class Toy: Model {
    static let database = beta

    static let keyStringMap: KeyStringMap = [
        key(\.id): "id",
        key(\.name): "name"
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
    static func prepare(on connection: SQLiteConnection) -> Completable {
        return connection.create(self) { schema in
            try schema.field(for: \.id)
            try schema.field(for: \.name)
        }
    }

    static func revert(on connection: SQLiteConnection) -> Completable {
        return connection.delete(self)
    }

}
