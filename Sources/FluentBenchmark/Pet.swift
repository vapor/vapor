import Async
import Fluent
import Foundation

internal final class Pet: Model {
    /// See Model.ID
    typealias ID = UUID

    /// See Model.name
    static var name: String {
        return "pet"
    }

    /// See Model.idKey
    static var idKey = \Pet.id

    /// See Model.keyFieldMap
    static var keyFieldMap = [
        key(\.id): field("id"),
        key(\.name): field("name"),
        key(\.ownerID): field("ownerID")
    ]

    /// Foo's identifier
    var id: ID?

    /// Name string
    var name: String

    /// Age int
    var ownerID: User.ID

    /// Create a new foo
    init(id: ID? = nil, name: String, ownerID: User.ID) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
    }
}

// MARK: Relations

extension Pet {
    /// A relation to this pet's owner.
    var owner: Parent<Pet, User> {
        return parent(\.ownerID)
    }

    /// A relation to this pet's toys.
    var toys: Siblings<Pet, Toy, PetToy> {
        return siblings()
    }
}

// MARK: Migration

internal struct PetMigration<D: Database>: Migration where D.Connection: SchemaSupporting {
    /// See Migration.database
    typealias Database = D

    /// See Migration.prepare
    static func prepare(on connection: Database.Connection) -> Future<Void> {
        return connection.create(Pet.self) { builder in
            try builder.id()
            try builder.field(for: \.name)
            try builder.field(for: \.ownerID)
        }
    }

    /// See Migration.revert
    static func revert(on connection: Database.Connection) -> Future<Void> {
        return connection.delete(Pet.self)
    }
}


