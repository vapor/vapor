import Async
import Core
import Fluent
import Foundation

public final class Pet<D: Database>: Model {
    /// See Model.Database
    public typealias Database = D

    /// See Model.ID
    public typealias ID = UUID

    /// See Model.name
    public static var name: String {
        return "pet"
    }

    /// See Model.idKey
    public static var idKey: IDKey { return \.id }

    /// See Model.keyStringMap
    public static var keyStringMap: KeyStringMap {
        return [
            key(\.id): "id",
            key(\.name): "name",
            key(\.ownerID): "ownerID"
        ]
    }

    /// See Model.database
    public static var database: DatabaseIdentifier<D> {
        return .init("test")
    }

    /// Foo's identifier
    var id: ID?

    /// Name string
    var name: String

    /// Age int
    var ownerID: User<Database>.ID

    /// Create a new foo
    init(id: ID? = nil, name: String, ownerID: User<Database>.ID) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
    }

    /// See Encodable.encode
    public func encode(to encoder: Encoder) throws {
        var container = encodingContainer(for: encoder)
        try container.encode(key: \Pet<Database>.id)
        try container.encode(key: \Pet<Database>.name)
        try container.encode(key: \Pet<Database>.ownerID)
    }
}

// MARK: Relations

extension Pet {
    /// A relation to this pet's owner.
    var owner: Parent<Pet, User<Database>> {
        return parent(\.ownerID)
    }
}

extension Pet where Database.Connection: JoinSupporting {
    /// A relation to this pet's toys.
    var toys: Siblings<Pet, Toy<Database>, PetToy<Database>> {
        return siblings()
    }
}

// MARK: Migration

internal struct PetMigration<D: Database>: Migration
    where D.Connection: SchemaSupporting & ReferenceSupporting
{
    /// See Migration.database
    typealias Database = D

    /// See Migration.prepare
    static func prepare(on connection: Database.Connection) -> Future<Void> {
        return connection.create(Pet<Database>.self) { builder in
            try builder.field(
                type: Database.Connection.FieldType.makeSchemaFieldType(for: .uuid),
                for: \Pet<Database>.id
            )
            try builder.field(
                type: Database.Connection.FieldType.makeSchemaFieldType(for: .string),
                for: \Pet<Database>.name
            )
            let base = try builder.field(
                type: Database.Connection.FieldType.makeSchemaFieldType(for: .uuid),
                for: \Pet<Database>.ownerID
            )
            let reference = SchemaReference(
                base: base,
                referenced: QueryField(entity: "users", name: "id")
            )
            builder.schema.addReferences.append(reference)
        }
    }

    /// See Migration.revert
    static func revert(on connection: Database.Connection) -> Future<Void> {
        return connection.delete(Pet<Database>.self)
    }
}


