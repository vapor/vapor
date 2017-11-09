import Async
import Fluent
import Foundation

internal final class User: Model, Timestampable {

    /// See Model.ID
    typealias ID = UUID

    /// See Model.idKey
    static var idKey = \User.id

    /// See Model.name
    static var entity: String {
        return "users"
    }

    /// See Model.keyFieldMap
    static var keyFieldMap = [
        key(\.id): field("id"),
        key(\.name): field("name"),
        key(\.age): field("age"),
        key(\.createdAt): field("createdAt"),
        key(\.updatedAt): field("updatedAt")
    ]

    /// Foo's identifier
    var id: UUID?

    /// Name string
    var name: String

    /// Age int
    var age: Int

    /// Timestampable.createdAt
    var createdAt: Date?

    /// Timestampable.updatedAt
    var updatedAt: Date?

    /// Create a new foo
    init(id: ID? = nil, name: String, age: Int) {
        self.id = id
        self.name = name
        self.age = age
    }
}

// MARK: Relations

extension User {
    /// A relation to this user's pets.
    var pets: Children<User, Pet> {
        return children(\.ownerID)
    }
}

// MARK: Migration

internal struct UserMigration<D: Database>: Migration where D.Connection: SchemaSupporting {
    /// See Migration.database
    typealias Database = D

    /// See Migration.prepare
    static func prepare(on connection: Database.Connection) -> Future<Void> {
        return connection.create(User.self) { builder in
            try builder.id()
            try builder.field(for: \.name)
            try builder.field(for: \.age)
            try builder.field(for: \.createdAt)
            try builder.field(for: \.updatedAt)
        }
    }

    /// See Migration.revert
    static func revert(on connection: Database.Connection) -> Future<Void> {
        return connection.delete(User.self)
    }
}
