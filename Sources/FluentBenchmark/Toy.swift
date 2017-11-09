import Async
import Fluent
import Foundation

internal final class Toy: Model {
    /// See Model.ID
    typealias ID = UUID

    /// See Model.name
    static var name: String {
        return "toy"
    }

    /// See Model.idKey
    static var idKey = \Toy.id

    /// See Model.keyFieldMap
    static var keyFieldMap = [
        key(\.id): field("id"),
        key(\.name): field("name")
    ]

    /// Foo's identifier
    var id: ID?

    /// Name string
    var name: String

    /// Create a new foo
    init(id: ID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: Relations

extension Toy {
    /// A relation to this toy's pets.
    var pets: Siblings<Toy, Pet, PetToy> {
        return siblings()
    }
}

// MARK: Migration

internal struct ToyMigration<D: Database>: Migration where D.Connection: SchemaSupporting {
    /// See Migration.database
    typealias Database = D

    /// See Migration.prepare
    static func prepare(on connection: Database.Connection) -> Future<Void> {
        return connection.create(Toy.self) { builder in
            try builder.id()
            try builder.field(for: \.name)
        }
    }

    /// See Migration.revert
    static func revert(on connection: Database.Connection) -> Future<Void> {
        return connection.delete(Toy.self)
    }
}



