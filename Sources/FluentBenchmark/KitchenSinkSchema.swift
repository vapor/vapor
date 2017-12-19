import Async
import Fluent
import Foundation

final class KitchenSink<D: Database>: Model {
    /// See Model.Database
    typealias Database = D

    /// See Model.ID
    typealias ID = String

    /// See Model.idKey
    static var idKey: IDKey { return \.id }

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
            try builder.addField(
                type: Database.Connection.FieldType.requireSchemaFieldType(for: UUID.self),
                name: "id"
            )
            try builder.addField(
                type: Database.Connection.FieldType.requireSchemaFieldType(for: String.self),
                name: "string"
            )
            try builder.addField(
                type: Database.Connection.FieldType.requireSchemaFieldType(for: Int.self),
                name: "int"
            )
            try builder.addField(
                type: Database.Connection.FieldType.requireSchemaFieldType(for: Double.self),
                name: "double"
            )
            try builder.addField(
                type: Database.Connection.FieldType.requireSchemaFieldType(for: Date.self),
                name: "date"
            )
        }
    }

    /// See Migration.revert
    static func revert(on connection: D.Connection) -> Future<Void> {
        return connection.delete(KitchenSink<Database>.self)
    }
}
