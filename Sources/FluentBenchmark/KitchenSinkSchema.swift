import Async
import Fluent

final class KitchenSink<D: Database>: Model {
    /// See Model.Database
    typealias Database = D

    /// See Model.ID
    typealias ID = String

    /// See Model.keyFieldMap
    static var keyFieldMap: KeyFieldMap {
        return [key(\.id): field("id")]
    }

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
            try builder.id()

            try builder.field(.string(nil), "string")
            try builder.field(.string(8), "stringEight")
            try builder.field(.string(16), "optionalStringSixteen", isOptional: true)

            try builder.field(.int, "int")
            try builder.field(.int, "optionalInt", isOptional: true)

            try builder.field(.double, "double")
            try builder.field(.double, "optionalDouble", isOptional: true)

            try builder.field(.data(8), "dataEight")
            try builder.field(.data(16), "optionalSDataSixteen", isOptional: true)

            try builder.field(.date, "date")
            try builder.field(.date, "optionalDate", isOptional: true)
        }
    }

    /// See Migration.revert
    static func revert(on connection: D.Connection) -> Future<Void> {
        return connection.delete(KitchenSink<Database>.self)
    }
}
