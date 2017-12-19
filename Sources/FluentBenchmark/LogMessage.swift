import Async
import Fluent
import Foundation

public final class LogMessage<D: Database>: Model {
    /// See Model.Database
    public typealias Database = D

    /// See Model.ID
    public typealias ID = Int

    /// See Model.name
    public static var name: String {
        return "logmessage"
    }

    /// See Model.idKey
    public static var idKey: IDKey { return \.id }

    /// See Model.database
    public static var database: DatabaseIdentifier<D> {
        return .init("test")
    }

    /// LogMessage's identifier
    var id: ID?

    /// Log message
    var message: String

    /// Create a new foo
    init(id: ID? = nil, message: String) {
        self.id = id
        self.message = message
    }
}

internal struct LogMessageMigration<D: Database>: Migration where D.Connection: SchemaSupporting {
    typealias Database = D

    static func prepare(on connection: D.Connection) -> Future<Void> {
        return connection.create(LogMessage<D>.self) { builder in
            try builder.field(for: \LogMessage<Database>.id)

            try builder.field(for: \LogMessage<Database>.message)
        }
    }

    static func revert(on connection: D.Connection) -> Future<Void> {
        return connection.delete(LogMessage<Database>.self)
    }
}
