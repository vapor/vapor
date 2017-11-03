import Async
import Fluent

final class KitchenSink: Model {
    /// See Model.ID
    typealias ID = String

    /// See Model.keyFieldMap
    static let keyFieldMap = [key(\.id): field("id")]

    /// See Model.idKey
    static let idKey = \KitchenSink.id

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
        return connection.create(KitchenSink.self) { builder in
            builder.id()

            builder.string("string")
            builder.string("stringEight", length: 8)
            builder.string("optionalStringSixteen", length: 16, isOptional: true)

            builder.int("int")
            builder.int("optionalInt", isOptional: true)

            builder.double("double")
            builder.double("optionalDouble", isOptional: true)

            builder.data("dataEight", length: 8)
            builder.data("optionalSDataSixteen", length: 16, isOptional: true)

            builder.date("date")
            builder.date("optionalDate", isOptional: true)
        }
    }

    /// See Migration.revert
    static func revert(on connection: D.Connection) -> Future<Void> {
        return connection.delete(KitchenSink.self)
    }
}
