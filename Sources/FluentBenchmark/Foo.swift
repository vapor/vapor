import Async
import Fluent
import Foundation

internal final class Foo: Model {
    /// See Model.ID
    typealias ID = UUID

    /// See Model.name
    static let name = "foo"

    /// See Model.idKey
    static var idKey = \Foo.id

    /// See Model.keyFieldMap
    static var keyFieldMap = [
        key(\.id): field("id"),
        key(\.bar): field("bar"),
        key(\.baz): field("baz")
    ]

    /// Foo's identifier
    var id: UUID?

    /// Test string
    var bar: String

    /// Test integer
    var baz: Int

    /// Create a new foo
    init(id: ID? = nil, bar: String, baz: Int) {
        self.id = id
        self.bar = bar
        self.baz = baz
    }
}

internal struct FooMigration<D: Database>: Migration where D.Connection: SchemaSupporting {
    /// See Migration.database
    typealias Database = D

    /// See Migration.prepare
    static func prepare(on connection: Database.Connection) -> Future<Void> {
        return connection.create(Foo.self) { builder in
            builder.id()
            builder.string("bar")
            builder.int("baz")
        }
    }

    /// See Migration.revert
    static func revert(on connection: Database.Connection) -> Future<Void> {
        return connection.delete(Foo.self)
    }
}
