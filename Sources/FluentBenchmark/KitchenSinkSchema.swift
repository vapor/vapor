import Async
import JunkDrawer
import Fluent

final class KitchenSink<D: Database>: Model {
    /// See Model.ID
    typealias ID = String

    /// See Model.keyStringMap
    static var keyStringMap: KeyStringMap {
        return [key(\.id): "id"]
    }

    /// See Model.idKey
    static var idKey: IDKey { return \.id }

    /// See Model.database
    static var database: DatabaseIdentifier<D> { return .init("kitchenSink") }

    /// KitchenSink's identifier
    var id: String?
}

internal struct KitchenSinkSchema<
    D: Database
>: Migration where D.Connection: SchemaSupporting {
    /// See Migration.Database
    typealias Database = D

    /// See Migration.prepare
    static func prepare(on connection: D.Connection) -> Future<Void> {
        return connection.create(KitchenSink<Database>.self) { builder in
            builder.addField(
                type: Database.Connection.FieldType.makeSchemaFieldType(for: .uuid),
                name: "id"
            )
            builder.addField(
                type: Database.Connection.FieldType.makeSchemaFieldType(for: .string),
                name: "string"
            )
            builder.addField(
                type: Database.Connection.FieldType.makeSchemaFieldType(for: .int),
                name: "int"
            )
            builder.addField(
                type: Database.Connection.FieldType.makeSchemaFieldType(for: .double),
                name: "double"
            )
            builder.addField(
                type: Database.Connection.FieldType.makeSchemaFieldType(for: .date),
                name: "date"
            )
        }
    }

    /// See Migration.revert
    static func revert(on connection: D.Connection) -> Future<Void> {
        return connection.delete(KitchenSink<Database>.self)
    }
}
